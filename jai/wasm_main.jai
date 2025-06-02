
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

get_random_seed    :: () -> u64 #foreign "wasm_get_random_number";
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

init_arena :: inline (arena: *ArenaAllocator, thread_count: s64)
{
	block := carve_memory_block(0, thread_count, WORKER_NR_OF_PAGES, TEMP_NR_OF_PAGES);
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
	
	init_arena(*MAIN_ARENA_ALLOCATOR, thread_count);
	context.allocator.data = *MAIN_ARENA_ALLOCATOR;

	init_thread_group(enable_logging=true, get_random_seed());
	for 1..thread_count-1
	{
		thread_arena_allocator := New(ArenaAllocator);
		init_arena(thread_arena_allocator, thread_count);
		
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

	run_thread(index);
}

#program_export
main :: () #c_call
{
	push_context,defer_pop CONTEXT;
	
	assert(INITTED == true);

	FREE(.Temp);
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
