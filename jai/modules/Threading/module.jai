#module_parameters () (
	WorkAvailable: Type = void,
	WorkCompleted: Type = void,
	MAX_THREAD_COUNT  : s64,
	THREAD_QUEUE_SIZE : s64,
	CACHE_LINE_SIZE   : s32 = 64,
	INTERNAL          : bool = false,
	LOGGING           : bool = false,
	ProcessAvailableWork := (available: *void)
	{
		assert(false, "ProcessAvailableWork function must be defined!");
	},
	ProcessCompletedWork := (available: *void, completed: *void)
	{
		assert(false, "ProcessCompletedWork function must be defined!");
	},
	GetCurrentTimestamp := () -> u64 { return 0; }
);

#assert WorkAvailable != void "WorkAvailable struct must be defined!";
#assert WorkCompleted != void "WorkCompleted struct must be defined!";


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

Thread :: AlignStructTo(CACHE_LINE_SIZE,
struct
{		
	index: s64;
	
	allocator: Allocator;

	semaphore: Semaphore;
	
	// TODO: Add debug info to known whether the same thread tries to lock
	// the mutex multiple times
	available_mutex: Mutex;
	completed_mutex: Mutex;
	// TODO: Think if this might be needed (one reason might be, since
	// jai does not have compiler barrier llvm might rearange the 
	// instructions order in optimise build) :SHUTDOWN_MUTEX
	// shutdown_\mutex: Mutex;
	
	available: Buffer(WorkAvailable);
	completed: WorkCompleted;
	
	running: bool;
	
	// TODO: Have some kind of debug info

});

#scope_export

ThreadGroup :: struct
{
	threads: Array(Thread, MAX_THREAD_COUNT-1);
	
	cursor: s64;

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

/////////////////////////////


/////////////////////////////
// Macros
/////////////////////////////

GET_COMPLETE_WORK :: (code: Code) #expand
{
	assert(THREAD_GROUP.initted);

	for *thread: THREAD_GROUP.threads
	{
PUSH_LOCK(*thread.completed_mutex, #code
{
		`completed := thread.completed;
		thread.completed = .{};
});

		#insert code;
	}
}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_thread_group :: inline (enable_logging: bool)
{
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
	thread.allocator = .{allocator_proc, arena};
	start(*thread.semaphore);
	start(*thread.available_mutex);
	start(*thread.completed_mutex);
	reserve(*thread.available, THREAD_QUEUE_SIZE,, thread.allocator);
}

// TODO: Implement work stealing
add_work :: inline (work: WorkAvailable)
{
	assert(THREAD_GROUP.initted);
	assert(!THREAD_GROUP.shutdown);

	thread := *THREAD_GROUP.threads[THREAD_GROUP.cursor];
	THREAD_GROUP.cursor += 1;
	
	if THREAD_GROUP.cursor == THREAD_GROUP.threads.stored
	{
		THREAD_GROUP.cursor = 0;
	}
	
PUSH_LOCK(*thread.available_mutex, #code
{
	entry := insert(*thread.available);
	entry.* = work;
	
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
		
		work: WorkAvailable = ---;
PUSH_LOCK(*thread.available_mutex, #code
{
		entry := delete(*thread.available);
		work = entry.*;
});

		inline ProcessAvailableWork(*work);

		write_message("Thread(%): work '%' executed\n", index, work);

PUSH_LOCK(*thread.completed_mutex, #code
{
		inline ProcessCompletedWork(*work, *thread.completed);
});

		FREE(.Temp);
	}
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
