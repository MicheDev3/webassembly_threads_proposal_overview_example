
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

// WORKER_REQUEST_TYPE
DISPATCH_WORK   :: 1;
CHECK_IF_DONE   :: 2;

// WORKER_RESPONSE_TYPE
WORK_DISPATCHED :: 0;
PROCESSING_WORK :: 1;
WORK_COMPLETED  :: 2;

POINT_COUNT       :: 1_000_004;
POINTS_PER_THREAD :: 10000;

SOA :: true;

SIMD :: false;

RUN_CHECK_GEOMETRY_WORK :: true;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

INITTED: bool = false;

CONTEXT: #Context;

GEOMETRY: Geometry;
CURRENT, TARGET: WorkCompleted;

DISPATCHED_TASKS_COUNT :s64;
COMPLETED_TASKS_COUNT  :s64;

SECONDARY_THREAD_COUNT: s64;

ENTROPY: Random_State;

AMOUNT: float;

ARENAS: Array(MemoryArena, MAX_THREAD_COUNT);

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
	base: *u8;
	size: s64;
}

/////////////////////////////


/////////////////////////////
// Foreigns
/////////////////////////////

get_random_seed    :: () -> u64 #foreign "wasm_get_random_seed";
carve_memory_block :: (
	memory_block_index: s64,
	memory_block_count: s64,
	worker_memory_size: s64
) -> MemoryBlock #foreign;

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

make_arena :: inline (index: s64, thread_count: s64) -> MemoryArena
{
	block := carve_memory_block(index, thread_count, WORKER_NR_OF_PAGES);
	result: MemoryArena = .{block.base, block.size, 0};
	
	return result;
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
	
	arena := insert(*ARENAS);
	arena.* = make_arena(0, thread_count);
	context.allocator.data = arena;

	init_thread_group(enable_logging=true);
	for 1..thread_count-1
	{
		arena := insert(*ARENAS);
		arena.* = make_arena(it, thread_count);
		init_thread(it);
	}
	
	GEOMETRY = make_geometry(POINT_COUNT, CACHE_LINE_SIZE);
	SECONDARY_THREAD_COUNT = thread_count-1;
	
	seed := get_random_seed();
	random_seed(*ENTROPY, seed);
	
	print("Test configurations:\n");
	print("    - soa:                     %\n", SOA                     ,, temp);
	print("    - simd:                    %\n", SIMD                    ,, temp);
	print("    - thread count:            %\n", thread_count            ,, temp);
	print("    - point count:             %\n", POINT_COUNT             ,, temp);
	print("    - points per thread:       %\n", POINTS_PER_THREAD       ,, temp);
	print("    - run check geometry work: %\n", RUN_CHECK_GEOMETRY_WORK ,, temp);
	print("\n"                                                          ,, temp);
	
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
	
	PUSH_ALLOCATOR(.{allocator_proc, *ARENAS[index]});
	
	context.temporary_storage = New(Temporary_Storage);
	set_initial_data(context.temporary_storage, TEMP_MEMORY_SIZE, ALLOCATE(TEMP_MEMORY_SIZE));

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
#if RUN_CHECK_GEOMETRY_WORK
{
			reset_geometry(*GEOMETRY);
}
			AMOUNT = random_get_within_range(*ENTROPY, 1.0, 100.0);
			
			rest: s64;
			points := POINTS_PER_THREAD;
			work_count := POINT_COUNT / points;
			if work_count*points < POINT_COUNT
			{
				rest = POINT_COUNT - work_count*points;
			}
			
			CURRENT = .{};			
			push_geometry_work(GEOMETRY, *TARGET, work_count, points, rest, AMOUNT);
	
			result = WORK_DISPATCHED;		
		}
		case CHECK_IF_DONE;
		{

			result = PROCESSING_WORK;
GET_COMPLETE_WORK(#code
{
			CURRENT += completed;
});

			if CURRENT >= TARGET {
#if RUN_CHECK_GEOMETRY_WORK
{
				check_geometry_work(GEOMETRY, AMOUNT);
}				
				result = WORK_COMPLETED;
			}
		}
		case; { assert(false, "invalid control flow type"); }
	}
	
	reset_temporary_storage();

	return result;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Basic"()(ENABLE_ASSERT=ASSERT);
#import "Common";
#import "Allocator";
#import "Random";
#import "Threading"()(
	WorkAvailable    =WorkAvailable,
	WorkCompleted    =WorkCompleted,
	MAX_THREAD_COUNT =MAX_THREAD_COUNT,
	THREAD_QUEUE_SIZE=256,
	CACHE_LINE_SIZE  =CACHE_LINE_SIZE,
	INTERNAL         =INTERNAL,
	LOGGING          =LOGGING,
	ProcessAvailableWork=process_available_work,
	ProcessCompletedWork=process_completed_work
);

/////////////////////////////
