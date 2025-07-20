
/////////////////////////////
// Library
/////////////////////////////

libc       :: #library,system "libc";
libpthread :: #library,system "libpthread";

/////////////////////////////


/////////////////////////////
// Loads
/////////////////////////////

#load "native_common.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

SCHED_FIFO    :: 1;

PROT_READ     :: 0x1;
PROT_WRITE    :: 0x2;

MAP_SHARED    :: 0x01;
MAP_ANONYMOUS :: 0x20;
MAP_POPULATE  :: 0x08000;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

pthread_t :: u64;

pthread_attr_t :: union
{
    __size:  [56] u8;
    __align: s64;
}

sched_param :: struct
{
    sched_priority: s32;
}

PlatformThread :: AlignStructTo(CACHE_LINE_SIZE, 
struct
{
	index:  u32;
	handle: pthread_t;
	
	attr: pthread_attr_t;
	param: sched_param;
	
	allocator: ArenaAllocator;
});

/////////////////////////////


/////////////////////////////
// Foreigns
/////////////////////////////

get_nprocs     :: ()                                                                                                                          -> s32   #foreign libc;
mmap           :: (__addr: *void, __len: u64, __prot: s32, __flags: s32, __fd: s32, __offset: s64)                                            -> *void #foreign libc;

pthread_create :: (__newthread: *pthread_t, __attr: *pthread_attr_t, __start_routine: #type (unknown0: *void) -> *void #c_call, __arg: *void) -> s32   #foreign libpthread;
pthread_join   :: (__th: pthread_t, __thread_return: **void)                                                                                  -> s32   #foreign libpthread;

pthread_attr_init           :: (__attr: *pthread_attr_t)                                                                                      -> s32   #foreign libpthread;
pthread_attr_setschedpolicy :: (__attr: *pthread_attr_t, __policy: s32)                                                                       -> s32   #foreign libpthread;
pthread_attr_setschedparam  :: (__attr: *pthread_attr_t, __param: *sched_param)                                                               -> s32   #foreign libpthread;


/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_arena :: inline (arena: *ArenaAllocator, total_size: s64, temp_size: s64)
{
	assert(total_size > temp_size);
	
	memory := mmap(null, cast(u64)total_size, PROT_READ|PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS|MAP_POPULATE, -1, 0);
	assert(memory != cast(*void)-1);
	
	main_size := total_size - temp_size;
	arena.main = .{memory,             main_size, 0};
	arena.temp = .{memory + main_size, temp_size, 0};
}

linux_thread_proc :: (params: *void) -> *void #c_call
{
	ctx: #Context;
	push_context,defer_pop ctx;
	
	thread: *PlatformThread = params;
	context.thread_index = thread.index;
	run_thread(thread.index);
	
	return null;
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
		thread.index = cast(u32)it;
		thread.param.sched_priority = 10;
		init_arena(*thread.allocator, main_memory_size, temp_memory_size);
		init_thread(thread.index, *thread.allocator);
		
		success = pthread_attr_init(*thread.attr) == 0;
		if !success { break; }
		
		success = pthread_attr_setschedpolicy(*thread.attr, SCHED_FIFO) == 0;
		if !success { break; }
		
		success = pthread_attr_setschedparam(*thread.attr, *thread.param) == 0;
		if !success { break; }

		success = pthread_create(*thread.handle, *thread.attr, linux_thread_proc, thread) == 0;
		if !success { break; }
		
		result[it] = thread;
	}
	
	return success, result;
}

platform_fini_threads :PlatformFiniThreads: (threads: Block(PlatformThread))
{
	for threads
	{
		pthread_join(it.handle, null);
	}
}

/////////////////////////////


/////////////////////////////
// EntryPoint
/////////////////////////////

main :: ()
{
	page_size := KIBIBYTES(4);
	main_memory_size   := align_forward(MAIN_MEMORY_SIZE  , page_size);
	temp_memory_size   := align_forward(TEMP_MEMORY_SIZE  , page_size);
	thread_memory_size := align_forward(THREAD_MEMORY_SIZE, page_size);
	
	allocator: ArenaAllocator;
	init_arena(*allocator, main_memory_size, temp_memory_size);
	context.allocator.data = *allocator;
	
	// NOTE: Leave 1 to the os
	core_count := cast(u32)get_nprocs() - 1;
	if core_count > MAX_THREAD_COUNT
	{
		core_count = cast(u32)MAX_THREAD_COUNT;
	}

	// NOTE: excluding the processor running the main thread
	thread_count := core_count - 1;
	
	now := current_time_monotonic();
	time_to_string :: (using ct: Calendar_Time) -> string
	{
		date_part :: #bake_arguments formatInt(minimum_digits = 2);
		
		timezone_name := ifx ct.time_zone == .UTC then "Z" else ""; // @Incomplete: Maybe determine local time zone name or offset
		
		time_string := tprint("%_%_%T%_%_%", year, date_part(month_starting_at_0 + 1), date_part(day_of_month_starting_at_0 + 1), date_part(hour), date_part(minute), date_part(second),, allocation=allocation(.Temp));

		return time_string;
	}

	today := time_to_string(to_calendar(current_time_consensus()));
	
	entropy: Random_State;
	random_seed(*entropy, cast(u64)(now.high));
	
	print_test_configurations(today, thread_count);
	
	single_threaded_stats := single_threaded_test(*entropy);
	multi\_threaded_stats := multi\_threaded_test(*entropy, thread_count, thread_memory_size, temp_memory_size);
	assert(single_threaded_stats.datapoints.stored == multi\_threaded_stats.datapoints.stored);
	
	print("Average gain: %\n", (single_threaded_stats.avg - multi\_threaded_stats.avg) /  multi\_threaded_stats.avg,, allocation=allocation(.Temp));

#if PRINT_CSV_DATAPOINTS
{
	print("Writting csv datapoints...\n",, allocation=allocation(.Temp));

	csv: String_Builder;
	filename := tprint("%_stats_%.csv", POINT_COUNT, today,, allocation=allocation(.Temp));
	
	print_to_builder(*csv, "single, multi\n",, allocation=allocation(.Temp));
	for 0..single_threaded_stats.datapoints.stored-1
	{
		single_datapoint := single_threaded_stats.datapoints[it];
		multi\_datapoint := multi\_threaded_stats.datapoints[it];
		
		print_to_builder(*csv, "%, %\n", single_datapoint, multi\_datapoint,, allocation=allocation(.Temp));
	}
	
	content := builder_to_string(*csv, do_reset=false,, allocation=allocation(.Temp));

	write_entire_file(filename, content);
}
	
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
#import "File";
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
