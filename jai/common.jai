
wake   :: (address: *s64)          #foreign;
wait   :: (address: *s64)          #foreign;
lock   :: (address: *s64)          #foreign;
unlock :: (address: *s64)          #foreign;
sleep  :: (address: *s64, ns: s64) #foreign;

MS2NS :: 1000000;

sleep :: (worker: *Worker, ms: s64)
{
	sleep(worker.sentinel, ms*MS2NS);
}
