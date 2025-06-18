
/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

INITTED: bool = false;
MAIN_ARENA_ALLOCATOR: ArenaAllocator;

CONTEXT: #Context;

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

MemoryBlock :: struct
{
	main_base: *u8;
	main_size: s64;
	
	temp_base: *u8;
	temp_size: s64;
}

/////////////////////////////


/////////////////////////////
// Foreigns
/////////////////////////////

get_random_seed    :: () -> u64 #foreign "wasm_get_random_seed";
carve_memory_block :: (
	memory_block_index: s64,
	memory_block_count: s64,
	worker_memory_size: s64,
	temp_memory_size: s64
) -> MemoryBlock #foreign;

notify_main_thread_flow_initialized    :: () #foreign "wasm_notify_main_thread_flow_initialized";

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_arena :: inline (arena: *ArenaAllocator, thread_count: s64, index: s64)
{
	block := carve_memory_block(index, thread_count, WORKER_NR_OF_PAGES, TEMP_NR_OF_PAGES);
	arena.main = .{block.main_base, block.main_size, 0};
	arena.temp = .{block.temp_base, block.temp_size, 0};
}

/////////////////////////////


/////////////////////////////
// Exports
/////////////////////////////

#program_export
init :: (thread_count: s64) #c_call
{
    push_context,defer_pop CONTEXT;
    
    assert(INITTED == false);
    assert(thread_count > 0 && thread_count <= MAX_THREAD_COUNT);
	
	init_arena(*MAIN_ARENA_ALLOCATOR, thread_count, 0);
	context.allocator.data = *MAIN_ARENA_ALLOCATOR;

	init_thread_group(enable_logging=true, get_random_seed());
	for 1..thread_count-1
	{
		thread_arena_allocator := New(ArenaAllocator);
		init_arena(thread_arena_allocator, thread_count, it);
		
		init_thread(it, thread_arena_allocator);
	}
	
	INITTED = true;
}

#program_export
run_worker :: (index: s64) #c_call
{
	ctx: #Context;
	push_context,defer_pop ctx;

	assert(INITTED == true);
	assert(index >= 0 && index <= MAX_THREAD_COUNT-1);

	print("run worker\n");
	run_thread(index);
}

#program_export
run_worker_control_flow :: (index: s64) #c_call
{
	ctx: #Context;
	push_context,defer_pop ctx;

	assert(INITTED == true);
	assert(index >= 0 && index <= MAX_THREAD_COUNT-1);

	// run_thread(index);

	print("sleep start\n");
	sleep(100);
	print("sleep done\n");
	notify_main_thread_flow_initialized();
}

DISPATCHED_TASKS_COUNT:s64;
COMPLETED_TASKS_COUNT:s64;

#program_export
dispatch_work :: () #c_call
{
	push_context,defer_pop CONTEXT;
	
	assert(INITTED == true);

	count := 100004;
	points_per_thread := 5;
	
	geometry: Geometry;
	init_geometry(*geometry, count);
	
	DISPATCHED_TASKS_COUNT = (count / points_per_thread);
	
	amount := 1.0;
	work_count: s64;
	while work_count < DISPATCHED_TASKS_COUNT
	{
		work: Work;
		work.type = .Geometry;
		work.geometry.positions = .{points_per_thread, geometry.positions.entries + work_count*points_per_thread};
		work.geometry.normals   = .{points_per_thread, geometry.normals\ .entries + work_count*points_per_thread};
		work.geometry.amount = amount;
		
		add_work(work);

		amount += 1.0;
		
		work_count += 1;
	}

	// NOTE: working out the rest
	if work_count*points_per_thread < count
	{
		offset := work_count*points_per_thread;

		work: Work;
		work.type = .Geometry;
		work.geometry.positions = .{count - offset, geometry.positions.entries + offset};
		work.geometry.normals   = .{count - offset, geometry.normals\ .entries + offset};
		work.geometry.amount = amount;
		
		add_work(work);
		
		DISPATCHED_TASKS_COUNT += 1;
	}

	COMPLETED_TASKS_COUNT = 0;

	FREE(.Temp);
}

#program_export
check_if_work_done :: ()->bool #c_call
{
	push_context,defer_pop CONTEXT;
	
	assert(INITTED == true);

	//
	// work_count: s64 = 0;
	// while work_count < DISPATCHED_TASKS_COUNT
	// {
		for *work_per_thread: get_completed_work()
		{
			count := work_per_thread.count;
			
			COMPLETED_TASKS_COUNT += work_per_thread.count;			
		}
		
		FREE(.Temp);
	// }
	return COMPLETED_TASKS_COUNT >= DISPATCHED_TASKS_COUNT;

	// FREE(.Temp);
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Basic"()(ENABLE_ASSERT=INTERNAL);
#import "Common";
#import "Allocator";
#import "Threading"()(
	Work             =Work,
	MAX_THREAD_COUNT =MAX_THREAD_COUNT,
	CACHE_LINE_SIZE  =CACHE_LINE_SIZE,
	LOGGING          =INTERNAL,
	ThreadProc       =thread_proc,
);

/////////////////////////////
