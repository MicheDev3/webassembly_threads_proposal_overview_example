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

#scope_file

Thread :: AlignToCacheLine(struct
{		
	index: s64;
	
	allocator: Allocator;

	semaphore: Semaphore;
	
	available_mutex: Mutex;
	completed_mutex: Mutex;
	// TODO: Think if this might be needed (one reason might be, since
	// jai does not have compiler barrier llvm might rearange the 
	// instructions order in optimise build) :SHUTDOWN_MUTEX
	// shutdown_\mutex: Mutex;
	
	available: WorkList;
	completed: WorkList;
	
	running: bool;
	
	// TODO: Have some kind of debug info
});

#scope_export

AlignToCacheLine :: struct (T: Type)
#modify 
{
    tis := cast(*Type_Info)T;
    return tis.type == .STRUCT, "Argument must be a struct.";
} {
    #insert -> string 
    {
        builder: String_Builder;
        info := type_info(T);

		print_to_builder(*builder, "	Base :: struct\n");
		print_to_builder(*builder, "	{\n");
        for * info.members 
        {
            print_to_builder(*builder, "        %: type_of(T.%);\n", it.name, it.name);  // Use type_of so we don't need to reference the string name of the type.
        }
		print_to_builder(*builder, "	}\n");
        
		print_to_builder(*builder, #string DONE
	DESIRED_SIZE :: #run align_forward(size_of(Base), %);
	
	using base: Base;
#place base;
	_: [DESIRED_SIZE] u8 = ---;
DONE, CACHE_LINE_SIZE
		);
		
		result := builder_to_string(*builder,, temp);
        return result;
    }
}

ThreadGroup :: struct
{
	threads: Array(Thread, MAX_THREAD_COUNT-1);
	
	entropy: Random_State;

	shutdown: bool;
	initted:  bool;

#if LOGGING
{
	logging: bool;
}

}

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

#scope_file

WorkList :: FreeLinkedList(Work, DOUBLE_LINK=true);

#scope_export

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_thread_group :: inline (enable_logging: bool, seed: u64)
{
	random_seed(*THREAD_GROUP.entropy, seed);
#if LOGGING
{
	if enable_logging { toggle_logging(); }
}
	THREAD_GROUP.initted = true;
}

init_thread :: inline (index: s64, arena: *ArenaAllocator)
{
	assert(THREAD_GROUP.initted);

	thread := insert(*THREAD_GROUP.threads);
	thread.index = index;
	start(*thread.semaphore);
	start(*thread.available_mutex);
	start(*thread.completed_mutex);
	thread.allocator = .{allocator_proc, arena};
	thread.available = make_free_list(Work, DOUBLE_LINK=true,, thread.allocator);
	thread.completed = make_free_list(Work, DOUBLE_LINK=true,, thread.allocator);	
}

add_work :: inline (work: Work)
{
	assert(THREAD_GROUP.initted);
	assert(!THREAD_GROUP.shutdown);

	random1 := cast(u32)random_get_within_range(*THREAD_GROUP.entropy, 0, cast(float)THREAD_GROUP.threads.stored);
	random2 := cast(u32)random_get_within_range(*THREAD_GROUP.entropy, 0, cast(float)THREAD_GROUP.threads.stored);
	
	thread1 := *THREAD_GROUP.threads[random1];
	thread2 := *THREAD_GROUP.threads[random2];

	thread := (
		ifx get_count(*thread1.available) > get_count(*thread2.available)
		then thread2 
		else thread1
	);
	
PUSH_LOCK(*thread.available_mutex, #code
{
	insert(*thread.available, work, ,, thread.allocator);
});

	write_message("ThreadGroup: '%' added to Thread(%)\n", work, thread.index);

	wake(*thread.semaphore);
}

run_thread :: (index: s64)
{
	assert(THREAD_GROUP.initted);

	thread := *THREAD_GROUP.threads[index];
	thread.running = true;
	PUSH_ALLOCATOR(thread.allocator);
	write_message("Thread(%): starting\n", index);

	defer
	{

	// TODO: :SHUTDOWN_MUTEX
// PUSH_LOCK(*thread.shutdown_\mutex, #code
// {
		
		close(*thread.semaphore);
		close(*thread.available_mutex);
		close(*thread.completed_mutex);

		write_message("Thread(%): terminated\n", index);
			
		SHUTDOWN();

		thread.running = false;
// });

	}

	// TODO: Will llvm in optimise complain about this?
	while !THREAD_GROUP.shutdown
	{
		wait(*thread.semaphore);
		if THREAD_GROUP.shutdown { break; }
		
		work: Work = ---;
		link: *WorkList.Link;
PUSH_LOCK(*thread.available_mutex, #code
{
		link = get_tail(*thread.available);
		assert(link != null);

		work = link.value;
		delete(*thread.available, link);
});

		inline ThreadProc(*work);
		write_message("Thread(%): work '%' executed\n", index, work);

PUSH_LOCK(*thread.completed_mutex, #code
{
		insert(*thread.completed, link);
});
		
		FREE(.Temp);
	}
}

get_completed_work :: () -> LinkedList(Block(Work))
{
	assert(THREAD_GROUP.initted);

	PUSH_ALLOCATOR_PARAMS(allocation(.Temp));

	result := make_list(Block(Work), DOUBLE_LINK=false);
	for *thread: THREAD_GROUP.threads
	{
		count: s64;
		head: *WorkList.Link;
PUSH_LOCK(*thread.completed_mutex, #code
{
		count = get_count(*thread.completed);
		head  = get_head (*thread.completed);
});
		
		block := insert(*result, .{});
		if count
		{
			reserve(*block.value, count);
			
			tail := head;
			sentinel := get_sentinel(*thread.completed);
			for 0..count-1
			{
				assert(tail != sentinel);
				block.value[it] = tail.value;
				
				tail = tail.next;
			}
			
PUSH_LOCK(*thread.completed_mutex, #code
{
			delete(*thread.completed, head, tail, count);
});
		}
		
		// write_message("Thread(%): completed % works\n", thread.index, count);
	}
	
	return result;
}

shutdown :: inline (wait_for_termination: bool = true)
{
	assert(THREAD_GROUP.initted);
	assert(!THREAD_GROUP.shutdown);

	THREAD_GROUP.initted = false;
	THREAD_GROUP.shutdown = true;
	write_message("ThreadGroup: shutting down\n");

	for *thread: THREAD_GROUP.threads
	{
		wake(*thread.semaphore);
	}
	
	while wait_for_termination
	{
		terminated := true;
		for *thread: THREAD_GROUP.threads
		{
			// TODO: :SHUTDOWN_MUTEX
// PUSH_LOCK(*thread.shutdown_\mutex, #code
// {
			terminated &= !thread.running;
// });
		}
		
		if terminated
		{
			break;
		}
	}	
}

#if LOGGING
{

write_message :: inline (format: string, args: ..Any)
{
	if THREAD_GROUP.logging
	{
		builder: String_Builder;
		print_to_builder(*builder, format, ..args              ,, allocation=allocation(.Temp));
		write_string(builder_to_string(*builder, do_reset=false,, allocation=allocation(.Temp)));
	}
} @PrintLike

toggle_logging :: inline ()
{
	THREAD_GROUP.logging = !THREAD_GROUP.logging;
	status := ifx THREAD_GROUP.logging "enabling" else "disabling";
	write_message("ThreadGroup: % logging\n", status);
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
