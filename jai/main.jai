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
}

worker_proc :: (worker: *Worker)
{
	// print("Worker(%): working\n", worker.index);
	
	write_worker_log(worker.index, "working");

	sleep(worker, 1000);
}

/*
  (global $__stack_pointer (;0;) (import "env" "__stack_pointer") (mut i64))
  (global $__stack_high    (;0;) (import "env" "__stack_high")    (mut i64))
  (global $__stack_low     (;0;) (import "env" "__stack_low")     (mut i64))
  (global $__heap_base     (;0;) (import "env" "__heap_base")     (mut i64))
  (global $__heap_end      (;0;) (import "env" "__heap_end")      (mut i64))

  (global $__stack_pointer (mut i64) (i64.const 1107248))
  
*/

