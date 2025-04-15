#import "Basic";

#load "common.jai";

wait   :: (address: *s64) #foreign;
lock   :: (address: *s64) #foreign;
unlock :: (address: *s64) #foreign;
sleep  :: (ms: float)     #foreign;

WORKERS: [..]Worker;

#program_export
init_workers :: (worker_count: s64) -> []Worker #c_call
{
	new_context: #Context;
	push_context new_context
	{
		print("spawing % workers", worker_count);
		for 0..worker_count
		{
			worker: Worker;
			worker.mutex     = New(s64);
			worker.semaphore = New(s64);
			worker.semaphore.* = 1;
			
			array_add(*WORKERS, worker);
		}
	}

	result := WORKERS;
	return result;
}

#program_export
worker_proc :: (worker_index: s32) #c_call
{
	new_context: #Context;
	push_context new_context
	{
		worker := WORKERS[worker_index];
		// TODO: Probably have a fence here
		while !worker.should_exit
		{
			print("worker(%): waiting for work", worker_index);
			wait(worker.semaphore);
			
			if worker.should_exit { break; }
			
			print("worker(%): requesting lock", worker_index);
			lock(worker.mutex);
			print("worker(%): computing work", worker_index);
			sleep(1000);
			unlock(worker.mutex);
			print("worker(%): unlocked", worker_index);
		}
	}
}

// TODO: Is there a way to avoid to have a main
main :: ()
{
	
}
