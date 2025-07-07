
/////////////////////////////
// Library
/////////////////////////////

libc     :: #library,system "libc";
libpthread :: #library,system "libpthread";

/////////////////////////////


/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

PROT_READ    :: 0x1;
PROT_WRITE   :: 0x2;

MAP_SHARED   :: 0x01;
MAP_ANONYMOUS :: 0x20;
MAP_POPULATE :: 0x08000;

ITERATIONS :: 1000;
LOGGING    :: false;

POINT_COUNT  :: 10_000_004;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

SUMMATIONS: Block(Summation);

COMPUTE_WORK_STATS: Statistics;

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

pthread_t :: u64;

pthread_attr_t :: union {
    __size:  [56] u8;
    __align: s64;
}

LinuxThread :: AlignStructTo(CACHE_LINE_SIZE, 
struct
{
	index:  u32;
	handle: pthread_t;
	
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
	
	thread: *LinuxThread = params;
	context.thread_index = thread.index;
	run_thread(thread.index);
	
	return null;
}

compute_work :: (geometries: Block(Geometry), thread_count: s64)
{
	for *geometries { reset_geometry(it); }
		
	start := rdtsc();
	
	current, target: WorkCompleted;
	push_geometry_work(geometries, *target, thread_count);
		
	while true
	{
		for *completed_per_thread: get_completed_work()
		{
			current += completed_per_thread;		
		}
		
		if current >= target
		{
			assert(current == target);
			compute_stats(*COMPUTE_WORK_STATS, rdtsc() - start);

			break;
		}
	}
	
	check_geometry_work(geometries);
}

/////////////////////////////


/////////////////////////////
// EntryPoint
/////////////////////////////

main :: ()
{
	all_thread_count := get_nprocs();
	if all_thread_count > MAX_THREAD_COUNT
	{
		all_thread_count = cast(s32)MAX_THREAD_COUNT;
	}

	// NOTE: excluding the processor running the main thread
	secondary_thread_count := all_thread_count - 1;
	
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

	threads: Block(LinuxThread);
	reserve(*threads, secondary_thread_count);
	for 0..secondary_thread_count-1
	{
		thread := New(LinuxThread);
		thread.index = cast(u32)it;
		init_arena(*thread.allocator, thread_memory_size, temp_memory_size);
		init_thread(thread.index, *thread.allocator);
		
		success := pthread_create(*thread.handle, null, linux_thread_proc, thread);
		assert(success ==  0);
		
		threads[it] = thread;
	}
	
	rest: s64;
	points := POINT_COUNT / all_thread_count;
	if all_thread_count*points < POINT_COUNT
	{
		rest = POINT_COUNT - all_thread_count*points; 
	}
	
	geometries: Block(Geometry);
	init_geometry(*geometries, all_thread_count, points, rest, CACHE_LINE_SIZE);

	reset_stats(*COMPUTE_WORK_STATS);

	start := rdtsc();
	for 1..ITERATIONS
	{	
		compute_work(geometries, secondary_thread_count);
		
		FREE(.Temp);
	}
	elapsed := rdtsc() - start;
	
	// TODO: Think more about how to time performance
	print_thread_group_stats(,, allocation=allocation(.Temp));
	print("\n",, allocation=allocation(.Temp));
	print("Process % iterations in % (% threads)\n", ITERATIONS, elapsed, all_thread_count ,, allocation=allocation(.Temp));
	print("    - compute work min = %\n", COMPUTE_WORK_STATS.min                           ,, allocation=allocation(.Temp));
	print("    - compute work avg = %\n", COMPUTE_WORK_STATS.avg/COMPUTE_WORK_STATS.count  ,, allocation=allocation(.Temp));
	print("    - compute work max = %\n", COMPUTE_WORK_STATS.max                           ,, allocation=allocation(.Temp));
	reset_stats(*COMPUTE_WORK_STATS);
	
	shutdown();
	
	for threads
	{
		pthread_join(it.handle, null);
	}
	
	return;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Atomics"()(LLVM=LLVM);
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
