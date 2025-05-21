#module_parameters () (
	Work: Type = void,
	MAX_THREAD_COUNT  : s64,
	THREAD_MEMORY_SIZE: s64,
	TEMP_MEMORY_SIZE  : s64,
	CACHE_LINE_SIZE   : s32 = 64,
	LOGGING           : bool = false,
	ThreadProc        := (data: *void)
	{
		assert(false, "ThreadProc function must be defined!");
	}
);

#assert Work != void "Work struct must be defined!";


/////////////////////////////
// Globals
/////////////////////////////

#scope_file

THREAD_GROUP: ThreadGroup;

#scope_export

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

ThreadGroup :: struct
{
    Thread :: struct 
    {
		Base :: struct
		{
			WorkList :: FreeLinkedList(*Work, DOUBLE_LINK=true);

			allocator: Allocator;
		
			semaphore: Semaphore;
			
			available_mutex: Mutex;
			completed_mutex: Mutex;
			
			available: WorkList;
			completed: WorkList;
		
#if LOGGING
{
			builder: String_Builder;
}
		
		}
	
        DESIRED_SIZE :: #run align_forward(size_of(Base), CACHE_LINE_SIZE);

        using base: Base;
#place base;
        _: [DESIRED_SIZE] u8 = ---;
    }

	threads: Array(Thread, MAX_THREAD_COUNT-1);
	
	shutdown: bool;

#if LOGGING
{
	logging: bool;
}

}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

add_work :: inline (type: s64)
{

}

run_thread :: inline (index: s64)
{
	thread := *THREAD_GROUP.threads[index];
	PUSH_ALLOCATOR(thread.allocator);
	
	write_message("Thread(%): starting\n", index);

	while !THREAD_GROUP.shutdown
	{
		wait(*thread.semaphore);
		if THREAD_GROUP.shutdown { break; }
		
		work: *Work = null;
		link: *thread.WorkList.Link;
PUSH_LOCK(*thread.available_mutex, #code
{
		link = last(*thread.available);
		assert(link != null);

		work = link.value;
		delete(*thread.available, link);
});

		write_message("Thread(%): executing work '%'\n", index, work.*);
		ThreadProc(work);
		write_message("Thread(%): work executed with message: '%'\n", index, builder_to_string(*thread.builder, do_reset=false));

PUSH_LOCK(*thread.completed_mutex, #code
{
		insert(*thread.completed, link);
});
		
		FREE(,, arena_type=TEMP);
	}
	
	write_message("Thread(%): terminating\n", index);	
	
	SHUTDOWN();
}

get_completed_work :: () -> LinkedList(Block(Work))
{
	PUSH_ALLOCATION_TYPE(TEMP);

	result: LinkedList(Block(Work));
	init(*result);

	for *thread: THREAD_GROUP.threads
	{

PUSH_LOCK(*thread.completed_mutex, #code
{
		count := count(*thread.completed);
		first := head (*thread.completed);
		reset(*thread.completed);
});
		
		block := insert(*result, Block.{});
		if count
		{
			reserve(block, count);
			
			last := first;
			while true
			{
				block[it_index] = last.value;
				
				if last.next == sentinel(*thread.completed)
				{
					break;
				}
				
				last = last.next;
			}
			
PUSH_LOCK(*thread.completed_mutex, #code
{
			delete(*thread.completed, first, last);
});

		}
		
	}
	
	return result;
}

shutdown :: inline ()
{
	write_message("Shutting down threads\n");

	THREAD_GROUP.shutdown = true;
	for *thread: THREAD_GROUP.threads
	{
		wake(*thread.semaphore);
	}
}

#scope_file

#if LOGGING
{

write_message :: inline (format: string, args: ..Any)
{
	if THREAD_GROUP.logging
	{
		builder: String_Builder;
		print_to_builder(*builder, format, args                ,, arena_type=TEMP);
		write_string(builder_to_string(*builder, do_reset=false,, arena_type=TEMP));
	}
} @PrintLike

toggle_logging :: inline ()
{
	THREAD_GROUP.logging = !THREAD_GROUP.logging;
	status := ifx THREAD_GROUP.logging "Enabling" else "Disabling";
	write_message("% logging for ThreadGroup", status);
}

}
else
{

write_message :: inline (#discard format: string, #discard args: ..Any)
{

} @PrintLike

toggle_logging :: inline ()
{

}

}

#scope_export

/////////////////////////////


/////////////////////////////
// Platform
/////////////////////////////

#if OS == .WASM
{

#scope_file

#program_export
init :: (thread_count: s64) #c_call
{
	ctx: #Context;
    push_context,defer_pop ctx;
    
    assert(INITTED == false);
    assert(thread_count > 0 && thread_count <= MAX_THREAD_COUNT);
	
	block := carve_memory_block(0, thread_count, THREAD_MEMORY_SIZE, TEMP_MEMORY_SIZE);
	main_arena_allocator := *MAIN_ARENA_ALLOCATOR;
	main_arena_allocator.main = .{block.main_base, block.main_size, 0};
	main_arena_allocator.temp = .{block.temp_base, block.temp_size, 0};

	for 1..thread_count-1
	{
		block := carve_memory_block(it, thread_count, THREAD_MEMORY_SIZE, TEMP_MEMORY_SIZE);
		thread_arena_allocator := New(ArenaAllocator,, Allocator.{allocator_proc, main_arena_allocator});
		thread_arena_allocator.main = .{block.main_base, block.main_size, 0};
		thread_arena_allocator.temp = .{block.temp_base, block.temp_size, 0};
	
		thread := insert(*THREAD_GROUP.threads);
		thread.semaphore = 1;
		thread.allocator = .{allocator_proc, thread_arena_allocator};
		thread.available = make_free_list(*Work, DOUBLE_LINK=true,, thread.allocator);
		thread.completed = make_free_list(*Work, DOUBLE_LINK=true,, thread.allocator);
	}
	
	write_message("Initialised '%' threads", thread_count-1);
	
	INITTED = true;
}

#program_export
add_work :: (type: s64) #c_call
{
	ctx: #Context;
    push_context,defer_pop ctx;

    assert(INITTED == true);
	add_work(type,, Allocator.{allocator_proc, *MAIN_ARENA_ALLOCATOR});
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

INITTED: bool = false;
MAIN_ARENA_ALLOCATOR: ArenaAllocator;

#scope_export

}
else
{
	// TODO: Support Windows
	#assert false "OS unknown or currently unsupported!";
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#scope_file

#import "Allocator";
#import "Basic";
#import "Common";

#scope_export

/////////////////////////////
