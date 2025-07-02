
/////////////////////////////
// Library
/////////////////////////////

kernel32 :: #library,system "kernel32";
crt      :: #library,system "msvcrt";

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

ITERATIONS :: 1000;
LOGGING    :: false;

SUMMATIONS_COUNT  :: 0;
// SUMMATIONS_COUNT  :: 10000;
POINTS_COUNT      :: 10_000_004;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

GEOMETRY: Geometry;

SUMMATIONS: Block(Summation);

PUSH_GEOMETRY_WORK_STATS:  Statistics;
WAIT_WORK_COMPLETED_STATS: Statistics;
COMPUTE_WORK_STATS:        Statistics;

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

Win64Thread :: AlignStructTo(CACHE_LINE_SIZE, 
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
	
	main_size := total_size - temp_size;
	arena.main = .{memory,             main_size, 0};
	arena.temp = .{memory + main_size, temp_size, 0};
}

win64_thread_proc :: (params: *void) -> u32 #c_call
{
	ctx: #Context;
	push_context,defer_pop ctx;
	
	thread: *Win64Thread = params;
	context.thread_index = thread.index;
	run_thread(thread.index);
	
	_endthreadex(0);
	return 0;
}

compute_work :: (thread_count: s64)
{
	start := rdtsc();

	seed := current_time_monotonic();
	// TODO: Check this is correct
	random_seed(cast,force(Some_Big_Time_Value)seed);

	// TODO: reimplement SUMMATIONS test
	reset_geometry(*GEOMETRY);
	// reset_summations(*SUMMATIONS);
	
	// summation_iterations := SUMMATIONS_COUNT;
	
	current, target: WorkCompleted;
	push_geometry_work(*target, thread_count, POINTS_COUNT, *PUSH_GEOMETRY_WORK_STATS);
	
	// summation_work_count: s64;
	// while summation_work_count < summation_iterations
	// {
	// 	work: WorkAvailable;
	// 	work.type = .Summation;
	// 	work.summation = *SUMMATIONS[summation_work_count];
	// 	work.summation.count = random_get() & 0xFF_FFFF;
	// 	if work.summation.count == 0 work.summation.count = 1;
		
	// 	add_work(work, sequentially=true);
		
	// 	summation_work_count += 1;
	// }
	
	start_wait := rdtsc();
	while true
	{
		for *completed_per_thread: get_completed_work()
		{
			current += completed_per_thread;		
		}
		
		if current >= target
		{
			assert(current == target);
		
			elapsed := rdtsc() - start_wait;
			if elapsed < WAIT_WORK_COMPLETED_STATS.min WAIT_WORK_COMPLETED_STATS.min = elapsed;
			if elapsed > WAIT_WORK_COMPLETED_STATS.max WAIT_WORK_COMPLETED_STATS.max = elapsed;
			WAIT_WORK_COMPLETED_STATS.avg += elapsed;	

			break;
		}
	}
	
	check_geometry_work(*GEOMETRY, thread_count, POINTS_COUNT);
	
	// for SUMMATIONS
	// {
	// 	result := (it.count * (it.count + 1)) / 2;
	// 	assert(it.result == result);
	// }	
}

/////////////////////////////


/////////////////////////////
// EntryPoint
/////////////////////////////

#program_export "main"
__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call
{
	init_synchronization();

	__command_line_arguments.count = argc;
	__command_line_arguments.data  = argv;
	
	ctx: #Context;
	push_context,defer_pop ctx;
	
	result := no_inline main();
	return result;
}

main :: () -> s32
{
	// NOTE: :OS_DEPENDENT
	//{
	thread_count := GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
	//}
	if thread_count > MAX_THREAD_COUNT
	{
		thread_count = cast(u32)MAX_THREAD_COUNT;
	}

	// NOTE: excluding the processor running the main thread
	thread_count -= 1;
	
	// TODO: Retrieve how big is a memory page
	page_size := KIBIBYTES(4);
	
	main_memory_size   := align_forward(MAIN_MEMORY_SIZE  , page_size);
	temp_memory_size   := align_forward(TEMP_MEMORY_SIZE  , page_size);
	thread_memory_size := align_forward(THREAD_MEMORY_SIZE, page_size);
	
	allocator: ArenaAllocator;
	init_arena(*allocator, main_memory_size, temp_memory_size);
	context.allocator.data = *allocator;
	
	seed := current_time_monotonic();
	init_thread_group(enable_logging=true, cast(u64)seed.high);

	// NOTE: :OS_DEPENDENT
	//{
	threads: Block(Win64Thread);
	reserve(*threads, thread_count);
	for 0..thread_count-1
	{
		thread := New(Win64Thread);
		thread.index = it;
		init_arena(*thread.allocator, thread_memory_size, temp_memory_size);
		init_thread(thread.index, *thread.allocator);
		
		ignored: s32;
		handle := _beginthreadex(null, 0, cast(*void)win64_thread_proc, thread, REALTIME_PRIORITY_CLASS, *ignored);
		assert(handle != null);
		
		thread.handle = cast(*void)handle;
		threads[it] = thread;
	}
	//}
	
	init_geometry(*GEOMETRY, POINTS_COUNT);
	init_summations(*SUMMATIONS, SUMMATIONS_COUNT);

	start := rdtsc();
	for 1..ITERATIONS
	{
		start := rdtsc();
		compute_work(thread_count);
		elapsed := rdtsc() - start;
		if elapsed < COMPUTE_WORK_STATS.min COMPUTE_WORK_STATS.min = elapsed;
		if elapsed > COMPUTE_WORK_STATS.max COMPUTE_WORK_STATS.max = elapsed;
		COMPUTE_WORK_STATS.avg += elapsed;
		
		FREE(.Temp);
	}
	
	WAIT_WORK_COMPLETED_STATS.avg /= cast(u64)ITERATIONS;
	PUSH_GEOMETRY_WORK_\STATS.avg /= cast(u64)ITERATIONS;
	COMPUTE_WORK_\      STATS.avg /= cast(u64)ITERATIONS;

	print("\n",, allocation=allocation(.Temp));
	print_thread_group_stats(,, allocation=allocation(.Temp));
	
	print("Process % iterations in % (% threads)\n", ITERATIONS, rdtsc() - start, thread_count,, allocation=allocation(.Temp));
	print("    - push geometry work   min = %\n", PUSH_GEOMETRY_WORK_\STATS.min,, allocation=allocation(.Temp));
	print("    - push geometry work   avg = %\n", PUSH_GEOMETRY_WORK_\STATS.avg,, allocation=allocation(.Temp));
	print("    - push geometry work   max = %\n", PUSH_GEOMETRY_WORK_\STATS.max,, allocation=allocation(.Temp));
	print("    - wait work completed  min = %\n", WAIT_WORK_COMPLETED_STATS.min,, allocation=allocation(.Temp));
	print("    - wait work completed  avg = %\n", WAIT_WORK_COMPLETED_STATS.avg,, allocation=allocation(.Temp));
	print("    - wait work completed  max = %\n", WAIT_WORK_COMPLETED_STATS.max,, allocation=allocation(.Temp));
	print("    - compute work         min = %\n", COMPUTE_WORK_\      STATS.min,, allocation=allocation(.Temp));
	print("    - compute work         avg = %\n", COMPUTE_WORK_\      STATS.avg,, allocation=allocation(.Temp));
	print("    - compute work         max = %\n", COMPUTE_WORK_\      STATS.max,, allocation=allocation(.Temp));
	COMPUTE_WORK_\      STATS = .{};
	WAIT_WORK_COMPLETED_STATS = .{};
	
	shutdown();
	
	// NOTE: :OS_DEPENDENT
	//{
	for threads
	{
		CloseHandle(it.handle);
	}
	//}

	return 0;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

// NOTE: :NATIVE_REQUIRED
//{
#import "Atomics"()(LLVM=LLVM);
//}
#import "Allocator";
#import "Machine_X64";
#import "Basic"()(ENABLE_ASSERT=INTERNAL);
#import "Common";
#import "Random";
#import "Threading"()(
	WorkAvailable       =WorkAvailable,
	WorkCompleted       =WorkCompleted,
	MAX_THREAD_COUNT    =MAX_THREAD_COUNT,
	THREAD_QUEUE_SIZE   =10000,
	CACHE_LINE_SIZE     =CACHE_LINE_SIZE,
	INTERNAL            =INTERNAL,
	LOGGING             =LOGGING,
	ProcessAvailableWork=process_available_work,
	ProcessCompletedWork=process_completed_work,
	GetCurrentTimestamp = () -> u64 { return rdtsc(); }
);

/////////////////////////////
