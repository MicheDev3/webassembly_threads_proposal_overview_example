
/////////////////////////////
// Library
/////////////////////////////

kernel32 :: #library,system "kernel32";

/////////////////////////////


/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

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

MAIN_ARENA_ALLOCATOR: ArenaAllocator;

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

Win64Thread :: struct
{
	Base :: struct
	{
		index: s64;
		
		allocator: ArenaAllocator;
	}
	
	DESIRED_SIZE :: #run align_forward(size_of(Base), CACHE_LINE_SIZE);
	
	using base: Base;
#place base;
	_: [DESIRED_SIZE] u8 = ---;
}

#assert (size_of(Win64Thread) == CACHE_LINE_SIZE);

/////////////////////////////


/////////////////////////////
// Foreigns
/////////////////////////////

GetActiveProcessorCount :: (GroupNumber: u16)                                                     -> u32   #foreign kernel32;
VirtualAlloc            :: (lpAddress: *void, dwSize: u64, flAllocationType: u32, flProtect: u32) -> *void #foreign kernel32;
VirtualFree             :: (lpAddress: *void, dwSize: u64, dwFreeType: u32)                       -> BOOL  #foreign kernel32;
CreateThread            :: (
	threadAttributes: *void,
	stackSize: s64,
	startAddress: *void,
	parameter: *void,
	creation_flags: Creation_Flags,
	threadIdReturn: *s32
) -> *void #foreign kernel32;
CloseHandle             :: (handle: *void)                                                        -> s32   #foreign kernel32;

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_arena :: inline (arena: *ArenaAllocator, total_size: s64, temp_size: s64)
{
	block := VirtualAlloc(null, cast(u64)total_size, MEM_RESERVE|MEM_COMMIT, PAGE_READWRITE);
	assert(block != null);
	
	main_size := total_size - temp_size;
	arena.main = .{block,             main_size, 0};
	arena.temp = .{block + main_size, temp_size, 0};
}

win64_thread_proc :: (params: *void) -> u32 #c_call
{
	ctx: #Context;
	push_context,defer_pop ctx;
	
	thread: *Win64Thread = params;
	run_thread(thread.index);
	
	return 0;
}

/////////////////////////////


/////////////////////////////
// EntryPoint
/////////////////////////////

#program_export "main"
__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call
{
	__command_line_arguments.count = argc;
	__command_line_arguments.data  = argv;
	
	ctx: #Context;
	push_context,defer_pop ctx;
	
	init_arena(*MAIN_ARENA_ALLOCATOR, MAIN_MEMORY_SIZE, TEMP_MEMORY_SIZE);
	context.allocator.data = *MAIN_ARENA_ALLOCATOR;
	
	result := no_inline main();
	return result;
}

main :: () -> s32
{
	toggle_logging();

	thread_count := GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
	if thread_count > MAX_THREAD_COUNT
	{
		thread_count = cast(u32)MAX_THREAD_COUNT;
	}
	// NOTE: excluding the processor running the main thread
	thread_count -= 1;
	
	for 0..thread_count-1
	{
		win64_thread := New(Win64Thread);
		win64_thread.index = it;
		init_arena(*win64_thread.allocator, THREAD_MEMORY_SIZE, TEMP_MEMORY_SIZE);
		init_thread(win64_thread.index, *win64_thread.allocator);
		
		ignored: s32;
		handle := CreateThread(null, 0, cast(*void)win64_thread_proc, win64_thread, 0, *ignored);
		assert(handle != null);
		CloseHandle(handle);
	}
	
	add_work(.{.Test1});
	add_work(.{.Test2});
	sleep(10000);
	
	shutdown();
	
	while true
	{
	
	}
	
	return 0;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Basic";
#import "Common";
#import "Allocator";
#import "Threading"()(
	Work             =Work,
	MAX_THREAD_COUNT =MAX_THREAD_COUNT,
	CACHE_LINE_SIZE  =CACHE_LINE_SIZE,
	LOGGING          =true,
	ThreadProc       =thread_proc
);

/////////////////////////////
