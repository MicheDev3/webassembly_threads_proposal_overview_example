
/////////////////////////////
// Structs
/////////////////////////////

Work :: struct
{

}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

main_proc :: (worker_group: *ThreadGroup)
{
	FREE(,, arena_type=TEMP);
}

/*
  (global $__stack_pointer (;0;) (import "env" "__stack_pointer") (mut i64))
*/

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Common";
#import "Allocator";
#import "Threading"()(
	Work              =Work,
	MAX_THREAD_COUNT  =MAX_THREAD_COUNT,
	LOGGING           =true,
	THREAD_MEMORY_SIZE= WORKER_NR_OF_PAGES,
	TEMP_MEMORY_SIZE  = TEMP_NR_OF_PAGES,
	ThreadProc        = (data: *void)
	{
		work := cast(*Work) data;

		sleep(1000);
	},
);

/////////////////////////////
