#add_context worker_group: *WorkerGroup;

Worker :: struct
{
	index:       s64;
	mutex:      *s64;
	semaphore:  *s64;
	
	sentinel:   *s64;
}

WorkerGroup :: struct
{
	workers: Array(Worker, 32);
	
	should_exit: bool;
}

terminate_workers :: ()
{
	group := context.worker_group;

	group.should_exit = true;
	for *worker: group.workers
	{
		wasm_wake(worker.semaphore);
	}
}

#scope_file

#program_export
worker_main :: (index: s64) #c_call
{
	new_context: #Context;
	push_context new_context
	{
		group := context.worker_group;

		worker := insert(*group.workers, .{});
		worker.index     = index;
		worker.mutex     = NEW(s64);
		worker.semaphore = NEW(s64);
		worker.sentinel  = NEW(s64);
		
		worker.semaphore.* = 1;

		// TODO: Probably have a fence here?
		if index == 0
		{
			pre_message := "Main: pre wasm\n";
			wasm_write_string(pre_message.count, pre_message.data, false);
			
			while !WORKER_GROUP.should_exit
			{

				main_proc(worker,, worker_group=*WORKER_GROUP);
			}
			
			post_message := "Main: post wasm\n";
			wasm_write_string(post_message.count, post_message.data, false);
		}
		else
		{
			pre_message := "Worker: pre wasm\n";
			wasm_write_string(pre_message.count, pre_message.data, false);

			while !WORKER_GROUP.should_exit
			{
				wasm_wait(worker.semaphore);
				if WORKER_GROUP.should_exit { break; }
				
				wasm_lock(worker.mutex);
				worker_proc(worker);
				wasm_unlock(worker.mutex);
			}
			
			post_message := "Worker: post wasm\n";
			wasm_write_string(post_message.count, post_message.data, false);
		}
	}
}

WORKER_GROUP: WorkerGroup;
