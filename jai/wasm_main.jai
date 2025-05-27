
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
// Functions
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Foreigns
/////////////////////////////

carve_memory_block :: (memory_block_index: s64, memory_block_count: s64, worker_memory_size: s64, temp_memory_size: s64) -> MemoryBlock #foreign;

/////////////////////////////


/////////////////////////////
// Exports
/////////////////////////////

#program_export
init :: (thread_count: s64) #c_call
{
	ctx: #Context;
    push_context,defer_pop ctx;
    
    assert(INITTED == false);
    assert(thread_count > 0 && thread_count <= MAX_THREAD_COUNT);
	
	block := carve_memory_block(0, thread_count, WORKER_NR_OF_PAGES, TEMP_NR_OF_PAGES);
	main_arena_allocator := *MAIN_ARENA_ALLOCATOR;
	main_arena_allocator.main = .{block.main_base, block.main_size, 0};
	main_arena_allocator.temp = .{block.temp_base, block.temp_size, 0};

	for 1..thread_count-1
	{
		block := carve_memory_block(it, thread_count, WORKER_NR_OF_PAGES, TEMP_NR_OF_PAGES);
		thread_arena_allocator := New(ArenaAllocator,, Allocator.{allocator_proc, main_arena_allocator});
		thread_arena_allocator.main = .{block.main_base, block.main_size, 0};
		thread_arena_allocator.temp = .{block.temp_base, block.temp_size, 0};
	
		init_thread(thread_arena_allocator);
	}
	
	write_message("Initialised '%' threads", thread_count-1);
	
	CONTEXT.allocator.data = main_arena_allocator;
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

#import "Basic";
#import "Common";
#import "Allocator";
#import "Threading"()(
	Work             =Work,
	MAX_THREAD_COUNT =MAX_THREAD_COUNT,
	LOGGING          =true,
	ThreadProc       =thread_proc,
);

/////////////////////////////
