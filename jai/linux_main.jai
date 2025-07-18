
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
		if !success { break }
		
		success = pthread_attr_setschedpolicy(*thread.attr, SCHED_FIFO) == 0;
		if !success { break }
		
		success = pthread_attr_setschedparam(*thread.attr, *thread.param) == 0;
		if !success { break }

		success = pthread_create(*thread.handle, *thread.attr, linux_thread_proc, thread) == 0;
		if !success { break }
		
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
	
	core_count := cast(u32)get_nprocs();

	single_threaded_stats := single_threaded_test(page_size);
	multi\_threaded_stats := multi\_threaded_test(core_count, page_size);
	
	print("Average gain: %\n", (single_threaded_stats.avg - multi\_threaded_stats.avg) /  multi\_threaded_stats.avg,, allocation=allocation(.Temp));
	
	return;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Atomics"()(LLVM=LLVM);
#import "Allocator";
#import "Basic"()(ENABLE_ASSERT=INTERNAL);
#import "Common";
#import "Machine_X64";
#import "Random";
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
