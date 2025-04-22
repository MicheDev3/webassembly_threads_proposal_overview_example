#import "Basic";

Worker :: struct
{
	index:       s64;
	mutex:      *s64;
	semaphore:  *s64;
	
	sentinel:   *s64;
}

init_workers :: () -> []Worker
{
	assert(!INITTED);

	// count := get_worker_count();
	count := 2;
	
	print("spawing % workers\n", count);
	for 1..count
	{
		worker: Worker;
		worker.index     = it;
		worker.mutex     = New(s64);
		worker.semaphore = New(s64);
		worker.sentinel  = New(s64);

		worker.semaphore.* = 1;
		
		array_add(*WORKERS, worker);
		
		push_worker(it);
	}

	INITTED = true;
	result := WORKERS;
	return result;
}

fini_workers :: ()
{
	assert(INITTED);
	
	SHOULD_EXIT = true;
	for *worker: WORKERS
	{
		wake(worker.semaphore);
	}
}

#program_export
worker_main :: (index: s64) #c_call
{
	new_context: #Context;
	push_context new_context
	{
		worker := *WORKERS[index-1];
		print("worker(%): running\n", worker.index);
		// TODO: Probably have a fence here
		while !SHOULD_EXIT
		{
			print("worker(%): waiting for work\n", worker.index);
			wait(worker.semaphore);
			assert(worker.semaphore.* >= 0);
			if SHOULD_EXIT { break; }
	
			print("worker(%): locking\n", worker.index);
			lock(worker.mutex);
			worker_proc(worker);
			unlock(worker.mutex);
			print("worker(%): unlocking\n", worker.index);
		}
		
		print("worker(%): exiting\n", index);
	}
}

#scope_file

get_worker_count :: () -> s64    #foreign;
push_worker      :: (index: s64) #foreign;

INITTED     := false;
SHOULD_EXIT := false;

WORKERS: [..]Worker;
