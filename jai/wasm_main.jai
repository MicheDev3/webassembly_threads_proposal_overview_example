
// TODO: Actually use the new code here

/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

LOGGING :: false;

POINTS_COUNT      :: 1_000_004;
POINTS_PER_THREAD :: 5;

// WORKER_REQUEST_TYPE
DISPATCH_WORK   :: 1;
CHECK_IF_DONE   :: 2;

// WORKER_RESPONSE_TYPE
WORK_DISPATCHED :: 0;
PROCESSING_WORK :: 1;
WORK_COMPLETED  :: 2;

POINT_COUNT     :: 1_000_004;

SIMD  :: false;
LANES :: 0;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

INITTED: bool = false;
MAIN_ARENA_ALLOCATOR: ArenaAllocator;

CONTEXT: #Context;

GEOMETRIES: Block(Geometry);
CURRENT, TARGET: WorkCompleted;

DISPATCHED_TASKS_COUNT :s64;
COMPLETED_TASKS_COUNT  :s64;

SECONDARY_THREAD_COUNT: s64;

ENTROPY: Random_State;

AMOUNT: float;

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

	seed := get_random_seed();
	init_thread_group(enable_logging=true, seed);
	for 1..thread_count-1
	{
		thread_arena_allocator := New(ArenaAllocator);
		init_arena(thread_arena_allocator, thread_count, it);
		
		init_thread(it, thread_arena_allocator);
	}
	
	rest: s64;
	points := POINT_COUNT / thread_count;
	if thread_count*points < POINT_COUNT
	{
		rest = POINT_COUNT - thread_count*points; 
	}
	
	init_geometry(*GEOMETRIES, thread_count, points, rest, CACHE_LINE_SIZE);
	SECONDARY_THREAD_COUNT = thread_count-1;
	
	random_seed(*ENTROPY, seed);
	
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
			AMOUNT = random_get_within_range(*ENTROPY, 1.0, 100.0);
			
			CURRENT = .{};			
			push_geometry_work(GEOMETRIES, *TARGET, AMOUNT);
			
			result = WORK_DISPATCHED;		
		}
		case CHECK_IF_DONE;
		{

			result = PROCESSING_WORK;
GET_COMPLETE_WORK(#code
{
			CURRENT += completed;
});
			work_is_done := CURRENT >= TARGET;
			if work_is_done {
				check_geometry_work(GEOMETRIES, AMOUNT);
				
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
#import "Random";
#import "Threading"()(
	WorkAvailable    =WorkAvailable,
	WorkCompleted    =WorkCompleted,
	MAX_THREAD_COUNT =MAX_THREAD_COUNT,
	THREAD_QUEUE_SIZE=100000,
	CACHE_LINE_SIZE  =CACHE_LINE_SIZE,
	INTERNAL         =INTERNAL,
	LOGGING          =LOGGING,
	ProcessAvailableWork=process_available_work,
	ProcessCompletedWork=process_completed_work
);

/////////////////////////////
