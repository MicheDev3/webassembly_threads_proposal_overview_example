#module_parameters () (
	Work: Type = void,
	MAX_THREAD_COUNT  : s64,
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

init_thread :: inline (arena: *ArenaAllocator)
{
	thread := insert(*THREAD_GROUP.threads);
	start(*thread.semaphore);
	start(*thread.available_mutex);
	start(*thread.completed_mutex);
	thread.allocator = .{allocator_proc, arena};
	thread.available = make_free_list(*Work, DOUBLE_LINK=true,, thread.allocator);
	thread.completed = make_free_list(*Work, DOUBLE_LINK=true,, thread.allocator);
}

add_work :: inline (work: Work)
{
	random1 := cast(u32)random_get_within_range(0, THREAD_GROUP.threads.stored);
	random2 := cast(u32)random_get_within_range(0, THREAD_GROUP.threads.stored);
	
	thread1 := *THREAD_GROUP.threads[random1];
	thread2 := *THREAD_GROUP.threads[random2];

	thread: *Thread = (
		ifx count(thread1.available) > count(thread2.available)
		then thread2 
		else thread1
	);
	
PUSH_LOCK(*thread.available_mutex, #code
{
	insert(*thread.completed, work, ,, thread.allocator);
});

	wake(*thread.semaphore);
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
		
		FREE(.Temp);
	}
	
	write_message("Thread(%): terminating\n", index);
	
	close(*thread.semaphore);
	close(*thread.available_mutex);
	close(*thread.completed_mutex);
	
	SHUTDOWN();
}

get_completed_work :: () -> LinkedList(Block(Work))
{
	PUSH_ALLOCATION_PARAMS(params(.Temp));

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

#if LOGGING
{

write_message :: inline (format: string, args: ..Any)
{
	if THREAD_GROUP.logging
	{
		builder: String_Builder;
		print_to_builder(*builder, format, args                ,, params=params(.Temp));
		write_string(builder_to_string(*builder, do_reset=false,, params=params(.Temp)));
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

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#scope_file

#import "Allocator";
#import "Basic";
#import "Common";
#import "Random";

#scope_export

/////////////////////////////
