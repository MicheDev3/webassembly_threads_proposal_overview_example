#load "common.jai";
#load "thread.jai";

COUNTER := 5;

main_proc :: (worker: *Worker)
{
	if COUNTER == 2
	{
		group := context.worker_group;
		wake(*group.workers[1]);
		wake(*group.workers[1]);
		wake(*group.workers[2]);
	}
	
	COUNTER -= 1;
	sleep(worker, 2000);

	if COUNTER == 0 { terminate_workers(worker); }
	
	FREE(,, allocator_type=Allocator.TEMP);
}

worker_proc :: (worker: *Worker)
{
	print("worker(%): working\n", worker.index, ,, allocator_type=Allocator.TEMP);
	
	sleep(worker, 1000);
	
	FREE(,, allocator_type=Allocator.TEMP);
}

/*
  (global $__stack_pointer (;0;) (import "env" "__stack_pointer") (mut i64))
*/

