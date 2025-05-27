

/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

/////////////////////////////


/////////////////////////////
// EntryPoint
/////////////////////////////

#program_export "main"
__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call
{
    __command_line_arguments.count = argc;
    __command_line_arguments.data  = argv;
    
    starting_context: #Context;
    initializer_of(#Context)(*starting_context);
    push_context,defer_pop starting_context;
        
    result := no_inline main();
    return result;
}

main :: () -> s32
{
	return 0;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Common";
#import "Allocator";
#import "Threading"()(
	Work             =Work,
	MAX_THREAD_COUNT =MAX_THREAD_COUNT,
	LOGGING          =true,
	ThreadProc       =thread_proc
);

/////////////////////////////
