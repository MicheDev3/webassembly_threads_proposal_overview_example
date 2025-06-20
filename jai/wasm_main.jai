
/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

POINTS_COUNT      :: 1_000_004;
POINTS_PER_THREAD :: 5;

// WORKER_REQUEST_TYPE
DISPATCH_WORK   :: 1;
CHECK_IF_DONE   :: 2;

// WORKER_RESPONSE_TYPE
WORK_DISPATCHED :: 0;
PROCESSING_WORK :: 1;
WORK_COMPLETED  :: 2;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

INITTED: bool = false;
MAIN_ARENA_ALLOCATOR: ArenaAllocator;

CONTEXT: #Context;

GEOMETRY: Geometry;
DISPATCHED_TASKS_COUNT :s64;
COMPLETED_TASKS_COUNT  :s64;

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

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

	assert(index >= 0 && index <= MAX_THREAD_COUNT-1);
	
	// TODO: Will llvm in optimise complain about this?
	while INITTED == false { sleep(100); }

	run_thread(index);
}

#program_export
run_worker_control_flow :: (type: s64) -> s64 #c_call
{
	push_context,defer_pop CONTEXT;

	assert(INITTED == true);

	result := -1;
	if type ==
	{
		case DISPATCH_WORK;
		{
			init_geometry(*GEOMETRY, POINTS_COUNT);
			
			COMPLETED_TASKS_COUNT  = 0;
			DISPATCHED_TASKS_COUNT = (POINTS_COUNT / POINTS_PER_THREAD);
			
			amount := 1.0;
			work_count: s64;
			while work_count < DISPATCHED_TASKS_COUNT
			{
				work: Work;
				work.type = .Geometry;
				work.geometry.positions = .{POINTS_PER_THREAD, GEOMETRY.positions.entries + work_count*POINTS_PER_THREAD};
				work.geometry.normals   = .{POINTS_PER_THREAD, GEOMETRY.normals\ .entries + work_count*POINTS_PER_THREAD};
				work.geometry.amount = amount;
				
				add_work(work);
				
				amount += 1.0;
				
				work_count += 1;
			}
			
			// NOTE: working out the rest
			if work_count*POINTS_PER_THREAD < POINTS_COUNT
			{
				offset := work_count*POINTS_PER_THREAD;
				
				work: Work;
				work.type = .Geometry;
				work.geometry.positions = .{POINTS_COUNT - offset, GEOMETRY.positions.entries + offset};
				work.geometry.normals   = .{POINTS_COUNT - offset, GEOMETRY.normals\ .entries + offset};
				work.geometry.amount = amount;
				
				add_work(work);
				
				DISPATCHED_TASKS_COUNT += 1;
			}
			
			result = WORK_DISPATCHED;		
		}
		case CHECK_IF_DONE;
		{
			result = PROCESSING_WORK;
			for *work_per_thread: get_completed_work()
			{
				COMPLETED_TASKS_COUNT += work_per_thread.count;
			}
			
			work_is_done := COMPLETED_TASKS_COUNT >= DISPATCHED_TASKS_COUNT;
			if work_is_done {
				print("COMPLETED_TASKS_COUNT:%\n", COMPLETED_TASKS_COUNT,, allocation=allocation(.Temp));
				amount := 0.0;
				for GEOMETRY.positions
				{
					if it_index % POINTS_PER_THREAD == 0
					{
						amount += 1;
					}
					
					normal   := GEOMETRY.normals[it_index];
					position := normal*amount;
					assert(it == position);
				}
				
				result = WORK_COMPLETED;
			}
		}
		case; { assert(false, "invalid control flow type"); }
	}
	
	FREE(.Temp);

	return result;
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
