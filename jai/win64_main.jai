
/////////////////////////////
// Library
/////////////////////////////

kernel32 :: #library,system "kernel32";
crt      :: #library,system "msvcrt";

/////////////////////////////


/////////////////////////////
// Loads
/////////////////////////////

#load "native_common.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

ALL_PROCESSOR_GROUPS :: 0xffff;

PAGE_READWRITE       :: 0x04;

MEM_COMMIT           :: 0x00001000;
MEM_RESERVE          :: 0x00002000;
MEM_RELEASE          :: 0x00008000;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

BOOL :: enum s32
{
	FALSE :: 0;
	TRUE  :: 1;
}

using Creation_Flags :: enum_flags u32 
{
	DEBUG_PROCESS                    :: 0x00000001;
	DEBUG_ONLY_THIS_PROCESS          :: 0x00000002;
	CREATE_SUSPENDED                 :: 0x00000004;
	DETACHED_PROCESS                 :: 0x00000008;
	
	CREATE_NEW_CONSOLE               :: 0x00000010;
	NORMAL_PRIORITY_CLASS            :: 0x00000020;
	IDLE_PRIORITY_CLASS              :: 0x00000040;
	HIGH_PRIORITY_CLASS              :: 0x00000080;
	
	REALTIME_PRIORITY_CLASS          :: 0x00000100;
	CREATE_NEW_PROCESS_GROUP         :: 0x00000200;
	CREATE_UNICODE_ENVIRONMENT       :: 0x00000400;
	CREATE_SEPARATE_WOW_VDM          :: 0x00000800;
	
	CREATE_SHARED_WOW_VDM            :: 0x00001000;
	CREATE_FORCEDOS                  :: 0x00002000;
	BELOW_NORMAL_PRIORITY_CLASS      :: 0x00004000;
	ABOVE_NORMAL_PRIORITY_CLASS      :: 0x00008000;
	
	INHERIT_PARENT_AFFINITY          :: 0x00010000;
	INHERIT_CALLER_PRIORITY          :: 0x00020000;    // Deprecated
	CREATE_PROTECTED_PROCESS         :: 0x00040000;
	EXTENDED_STARTUPINFO_PRESENT     :: 0x00080000;
	
	PROCESS_MODE_BACKGROUND_BEGIN    :: 0x00100000;
	PROCESS_MODE_BACKGROUND_END      :: 0x00200000;
	CREATE_SECURE_PROCESS            :: 0x00400000;
	
	CREATE_BREAKAWAY_FROM_JOB        :: 0x01000000;
	CREATE_PRESERVE_CODE_AUTHZ_LEVEL :: 0x02000000;
	CREATE_DEFAULT_ERROR_MODE        :: 0x04000000;
	CREATE_NO_WINDOW                 :: 0x08000000;
	
	PROFILE_USER                     :: 0x10000000;
	PROFILE_KERNEL                   :: 0x20000000;
	PROFILE_SERVER                   :: 0x40000000;
	CREATE_IGNORE_SYSTEM_DEFAULT     :: 0x80000000;
}

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

PlatformThread :: AlignStructTo(CACHE_LINE_SIZE, 
struct
{
	index:  u32;
	handle: *void;
	
	allocator: ArenaAllocator;
});

/////////////////////////////


/////////////////////////////
// Foreigns
/////////////////////////////

GetActiveProcessorCount :: (GroupNumber: u16)                                                     -> u32   #foreign kernel32;
VirtualAlloc            :: (lpAddress: *void, dwSize: u64, flAllocationType: u32, flProtect: u32) -> *void #foreign kernel32;
VirtualFree             :: (lpAddress: *void, dwSize: u64, dwFreeType: u32)                       -> BOOL  #foreign kernel32;
CloseHandle             :: (handle: *void)                                                        -> s32   #foreign kernel32;
// NOTE: Jai currently uses the crt lib so we must use crt threading functions
// https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/beginthread-beginthreadex?view=msvc-170
//{
_beginthreadex :: (
	_Security: *void,
	_StackSize: u32,
	_StartAddress: *void,
	_ArgList: *void,
	_InitFlag: Creation_Flags,
	_ThrdAddr: *s32
) -> *u32 #foreign crt;
_endthreadex :: (return_code: u32) #foreign crt;
//}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_arena :: inline (arena: *ArenaAllocator, total_size: s64, temp_size: s64)
{
	assert(total_size > temp_size);
	
	memory := VirtualAlloc(null, cast(u64)total_size, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE);
	assert(memory != null);
	
	main_size := total_size - temp_size;
	arena.main = .{memory,             main_size, 0};
	arena.temp = .{memory + main_size, temp_size, 0};
}

win64_thread_proc :: (params: *void) -> u32 #c_call
{
	ctx: #Context;
	push_context,defer_pop ctx;
	
	thread: *PlatformThread = params;
	context.thread_index = thread.index;
	run_thread(thread.index);
	
	_endthreadex(0);
	return 0;
}

platform_init_threads :PlatformInitThreads: 
(
	thread_count: u32,
	main_memory_size: s64,
	temp_memory_size: s64
) -> bool, Block(PlatformThread)
{
	success: bool = true;
	result: Block(PlatformThread);
	reserve(*result, thread_count);
	for 0..thread_count-1
	{
		thread := New(PlatformThread);
		thread.index = it;
		init_arena(*thread.allocator, main_memory_size, temp_memory_size);
		init_thread(thread.index, *thread.allocator);
		
		ignored: s32;
		handle := _beginthreadex(null, 0, cast(*void)win64_thread_proc, thread, REALTIME_PRIORITY_CLASS, *ignored);
		success = handle != null;
		if !success { break; }
		
		thread.handle = cast(*void)handle;
		result[it] = thread;
	}
	
	return success, result;
}

platform_fini_threads :PlatformFiniThreads: (threads: Block(PlatformThread))
{
	for threads
	{
		CloseHandle(it.handle);
	}
}

/////////////////////////////


/////////////////////////////
// EntryPoint
/////////////////////////////

main :: ()
{
	// TODO: Retrieve how big is a memory page
	// https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getlogicalprocessorinformation
	page_size := KIBIBYTES(4);
	
	// NOTE: Leave 1 to the os
	core_count := GetActiveProcessorCount(ALL_PROCESSOR_GROUPS) - 1;
	if core_count > MAX_THREAD_COUNT
	{
		core_count = cast(u32)MAX_THREAD_COUNT;
	}

	// NOTE: excluding the processor running the main thread
	thread_count := core_count - 1;
	
	seed := cast(u64)(current_time_monotonic().high);
	
	entropy: Random_State;
	random_seed(*entropy, seed);
	
	print_test_configurations(thread_count);
	
	single_threaded_stats := single_threaded_test(*entropy,               page_size);
	multi\_threaded_stats := multi\_threaded_test(*entropy, thread_count, page_size);
	
	print("Average gain: %\n", (single_threaded_stats.avg - multi\_threaded_stats.avg) /  multi\_threaded_stats.avg,, allocation=allocation(.Temp));
	
	return;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Atomics"()(LLVM=LLVM);
#import "Allocator";
#import "Basic"()(ENABLE_ASSERT=ASSERT);
#import "Common";
#import "Machine_X64";
#import "Random";
#if SIMD
{
#if AVX { #import "Simd/AVX"; }
else    { #import "Simd/SSE"; }
}
#import "Threading"()(
	WorkAvailable       =WorkAvailable,
	WorkCompleted       =WorkCompleted,
	MAX_THREAD_COUNT    =MAX_THREAD_COUNT,
	THREAD_QUEUE_SIZE   =256,
	CACHE_LINE_SIZE     =CACHE_LINE_SIZE,
	INTERNAL            =INTERNAL,
	LOGGING             =LOGGING,
	ProcessAvailableWork=process_available_work,
	ProcessCompletedWork=process_completed_work,
	GetCurrentTimestamp = () -> u64 { return rdtsc(); }
);

/////////////////////////////
