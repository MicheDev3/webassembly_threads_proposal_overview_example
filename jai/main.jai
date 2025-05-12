#load "common.jai";
#load "thread.jai";

COUNTER := 5;

main_proc :: (worker: *Worker)
{
	if COUNTER == 3
	{
		group := context.worker_group;
		wasm_wake(group.workers[1].semaphore);
		wasm_wake(group.workers[1].semaphore);
		// wasm_wake(group.workers[2].semaphore);
	}
	 
	COUNTER -= 1;
	// pre_message := "Main: sleeping\n";
	// wasm_write_string(pre_message.count, pre_message.data, false);
	sleep(worker, 1000);
	if COUNTER == 0 { terminate_workers(); }
}

worker_proc :: (worker: *Worker)
{
	post_message := "Worker: working\n";
	wasm_write_string(post_message.count, post_message.data, false);
		
	sleep(worker, 1000);
}

/*
  (global $__stack_pointer (;0;) (import "env" "__stack_pointer") (mut i64))
  (global $__stack_high (;0;) (import "env" "__stack_high") (mut i64))
  (global $__stack_low (;0;) (import "env" "__stack_low") (mut i64))

  (global $__stack_pointer (mut i64) (i64.const 1107248))
  
*/

