#import "Basic";
#import "Random";

#load "common.jai";
#load "thread.jai";

worker_proc :: (worker: *Worker)
{
	sleep(worker, 5000);
}

main :: ()
{
	workers := init_workers();
	
	worker0 := *workers[0];
	worker1 := *workers[1];
	wake(worker0.semaphore);
	wake(worker0.semaphore);
	
	// fini_workers();
	
	// for 0..4
	// {
	// 	index := random_get() % cast(u64)workers.count;
	// 	worker := *workers[index];
	// 	wake(worker.semaphore);
	// 	sleep(5000);
	// }
	
	// sleep(1000);
	
	// for *(workers)
	// {
	// 	it.should_exit = true;
	// 	wake(it.semaphore);
	// }
}





