#add_context worker_group: *WorkerGroup;

Worker :: struct
{
	index:       s64;
	mutex:      *s64;
	semaphore:  *s64;
}

WorkerGroup :: struct
{
	workers: Array(Worker, MAX_NUMBER_OF_WORKERS);
	
	should_exit: bool;
}

terminate_workers :: (worker: *Worker)
{
	group := context.worker_group;

	print("worker(%): waking workers for termination\n", worker.index,, allocator_type=Allocator.TEMP);

	group.should_exit = true;
	for *worker: group.workers
	{
		wake(worker);
	}
}

#scope_file

WORKER_GROUP: WorkerGroup;

#program_export
worker_main :: (worker_index: s64, worker_count: s64) #c_call
{
	new_context: #Context;
	push_context new_context
	{
		arena_allocator := Allocator.make_arena_allocator(worker_index, worker_count, WORKER_NR_OF_PAGES, TEMP_NR_OF_PAGES);
		context.allocator = .{Allocator.allocator_proc, *arena_allocator};
		
		insert(*WORKER_GROUP.workers, worker_index, .{worker_index, New(s64), New(s64)});
		
		worker := *WORKER_GROUP.workers[worker_index];
		worker.semaphore.* = 1;
		print("worker(%): starting\n", worker.index,, allocator_type=Allocator.TEMP);

		// TODO: Probably have a fence here?
		if worker.index == 0
		{			
			while !WORKER_GROUP.should_exit
			{
				main_proc(worker,, worker_group=*WORKER_GROUP);
			}
		}
		else
		{
			while !WORKER_GROUP.should_exit
			{	
				wait(worker);
				if WORKER_GROUP.should_exit { break; }
				
				// TODO: look only while pulling the work data
				lock(worker);
				defer unlock(worker);
				
				worker_proc(worker);
			}
			
		}
		
		print("worker(%): terminating\n", worker.index,, allocator_type=Allocator.TEMP);
	}
}

#scope_export
