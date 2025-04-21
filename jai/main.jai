#import "Basic";
#import "Random";

#load "common.jai";
#load "thread.jai";

worker_proc :: (worker: Worker)
{
	print("worker(%): doing some work\n", worker.index);
	sleep(1000);
}

main :: ()
{
	workers := init_workers();
	
	// print("Start Sleeping\n");
	// sleep(1000);
	// print("Done Sleeping\n");
	
	worker := *workers[0];
	wake(worker.semaphore);
	
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





