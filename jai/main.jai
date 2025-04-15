#import "Basic";
#import "Random";

#load "common.jai";

sleep  :: (ms: float)     #foreign;
wake   :: (address: *s64) #foreign;
get_worker_count :: () -> s64 #foreign;
push_worker  :: (worker_index: s64) #foreign;
init_workers :: (worker_count: s64) -> []Worker #foreign;

main :: ()
{
	a := New(s64);
	a.* = 10;
	print("A(%): %\n", a, a.*);
	
	// TODO: This is not working understand why. I think the issue might be related with
	// a mismatch between __stack_pointer between module or something like that
	workers := init_workers(get_worker_count());
	for *workers
	{
		push_worker(it_index);
	}
	
	// sleep(1000);
	
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





