#load "common.jai";
#load "thread.jai";

COUNTER := 5;

main_proc :: (worker: *Worker)
{
	COUNTER -= 1;
	sleep(worker, 1000);
	if COUNTER == 0 { terminate_workers(); }
}

worker_proc :: (worker: *Worker)
{
	sleep(worker, 1000);
}