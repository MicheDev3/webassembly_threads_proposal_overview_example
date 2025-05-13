#add_context worker_group: *WorkerGroup;

Worker :: struct
{
	index:       s64;
	mutex:      *s64;
	semaphore:  *s64;
}

WorkerGroup :: struct
{
	workers: Array(Worker, 32);
	
	should_exit: bool;
}

terminate_workers :: (worker: *Worker)
{
	group := context.worker_group;

	write_worker_log(worker.index, "waking workers for termination");

	group.should_exit = true;
	for *worker: group.workers
	{
		wake(worker);
	}
}

#scope_file

#program_export
worker_main :: (index: s64) #c_call
{
	new_context: #Context;

	push_context new_context
	{
		mutex    := 0;
		sentinel := 0;
		insert(*WORKER_GROUP.workers, index, .{index, *mutex, *sentinel});

		// insert(*WORKER_GROUP.workers, index, .{index, New(s64), New(s64)});
		
		worker := *WORKER_GROUP.workers[index];
		worker.semaphore.* = 1;
		write_worker_log(worker.index, "starting");

		// print("Worker: %\n", worker.*);
		// TODO: Probably have a fence here?
		if index == 0
		{
			// print("Main(%): starting\n", index);
									
			while !WORKER_GROUP.should_exit
			{
				main_proc(worker,, worker_group=*WORKER_GROUP);
			}			
			// print("Main(%): exiting\n", index);
		}
		else
		{
			// print("Worker(%): starting\n", index);
			
			while !WORKER_GROUP.should_exit
			{	
				wait(worker);
				if WORKER_GROUP.should_exit { break; }
				
				// TODO: look only while pulling the work data
				lock(worker);
				defer unlock(worker);
				
				worker_proc(worker);
			}
			
			// print("Worker(%): exiting\n", index);
		}
		
		write_worker_log(worker.index, "terminating");
	}
}

WORKER_GROUP: WorkerGroup;
