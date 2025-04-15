#import "Basic";

wake  :: (address: s64) #foreign;
sleep :: (ms: float)    #foreign;

main :: ()
{
	print("This is from Jai\n");
	sleep(100);
}