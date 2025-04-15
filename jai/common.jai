Worker :: struct
{
	should_exit: bool;
	mutex:      *s64;
	semaphore:  *s64;
}
