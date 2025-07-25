//
// Runtime_Support is less volatile than Preload and contains imports and various biggish code;
// it is considered reasonable that you can mess around with Runtime_Support and ship your own
// version of it.
//

#module_parameters(DEFINE_SYSTEM_ENTRY_POINT: bool, DEFINE_INITIALIZATION: bool, ENABLE_BACKTRACE_ON_CRASH: bool);

// NOTE: Required to build for unix oses.
OS_IS_UNIX :: OS == .MACOS || OS == .LINUX || OS == .PS5 || OS == .IOS || OS == .ANDROID;

// @Cleanup: __element_duplicate should lose its c_call status, and also be faster...!
__element_duplicate :: (start: *u8, num_elements: s64, size: s64) #c_call #no_aoc
{
	cursor := start + size;
	for 1..num_elements-1 
	{
		memcpy(cursor, start, size);
		cursor += size;
	}
}

write_number :: (number: u64, base := 10, negative := false) -> string #no_context #no_abc #no_aoc
{
	if number == 0 { return "0"; }
	
	if base > 16  base = 16;
	if base < 2   base = 2;
	
	ubase := cast,no_check(u64)base;
	
	// This is of course a horrible hack.
	// A u64 in base 2 can be up to 64 digits,
	// so we need at least that much space. Add a few more digits for superstition.
	buf: [69] u8;
	
	starting_cursor : s32 = buf.count;
	cursor := starting_cursor;
	
	while number
	{
		cursor -= 1;
		index := number % ubase;
		if index <= 9 { buf[cursor] = cast(u8)(index      + #char "0"); }
		else          { buf[cursor] = cast(u8)(index - 10 + #char "a"); }
		number /= ubase;
	}
	
	if negative
	{
		cursor -= 1;
		buf[cursor] = #char "-";
	}
	
	result: string = ---;
	result.data  = buf.data + cursor;
	result.count = starting_cursor - cursor;
	
	return result;
}

write_number :: (number: s64, base := 10) -> string #no_context
{
	result := write_number(cast,no_check(u64)number, base, number < 0);
	
	return result;
}

runtime_support_assertion_failed :: (loc: Source_Code_Location, message: string) -> bool
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);
	
	write_loc(loc, to_standard_error = true);
	write_string_unsynchronized(": Assertion failed", to_standard_error = true);
	
	if message
	{
		write_strings_unsynchronized(": ", message, "\n", to_standard_error = true);
	}
	else
	{
		write_string_unsynchronized("!\n", to_standard_error = true);
	}
	
	print_stack_trace :: (node: *Stack_Trace_Node)
	{  // @Copypasta from modules/Basic, but without calling print.
		while node
		{
			// There are two different line numbers available.
			// node.info.location has a line number, but this is the location of
			// the start of the procedure. That may be useful in some cases, but often
			// what we really want is the line number of the procedure call, which is
			// stored in node.line_number. That's what we print in this case.
			
			if node.info
			{
				write_string_unsynchronized(node.info.location.fully_pathed_filename, to_standard_error = true);
				write_string_unsynchronized(":", to_standard_error = true);
				write_string_unsynchronized(write_number(cast(u64)node.line_number), to_standard_error = true);
				write_string_unsynchronized(": ", to_standard_error = true);
				if node.info.name write_string_unsynchronized(node.info.name, to_standard_error = true);
				else write_string_unsynchronized("(anonymous procedure)", to_standard_error = true);
				write_string_unsynchronized("\n", to_standard_error = true);
			}
			
			node = node.next;
		}
	}
	
	if context.stack_trace
	{
		write_string_unsynchronized("\nStack trace:\n", to_standard_error = true);
		print_stack_trace(context.stack_trace);
	}
	else
	{
		write_string_unsynchronized("Exiting.\n", to_standard_error = true);
	}
	
	__runtime_support_disable_stack_trace = true;
	
	return true;
}

runtime_support_default_logger :: (message: string, data: *void, info: Log_Info)
{
	if !message then return;

	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);
	
	to_standard_error := (info.common_flags & .ERROR) != 0;
	
	if message[message.count-1] != #char "\n"
	{
		write_strings_unsynchronized(message, "\n", to_standard_error = to_standard_error);
	}
	else
	{
		write_string_unsynchronized(message, to_standard_error = to_standard_error);
	}
}

c_style_strlen :: (str: *u8) -> s64 #no_context
{
	p := str;
	while p.*  { p += 1; }
	return p - str;
}

to_string :: (c_string: *u8) -> string #no_context
{
	if c_string == null return "";
	
	s: string = ---;
	s.data = c_string;
	s.count = c_style_strlen(c_string);
	
	return s;
}

// @Incomplete: Pass loc to Runtime_Support versions.
__array_bounds_check_fail :: (index: s64, limit: s64, line_number: s64, filename: *u8) #no_context
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);
	
	// @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
	write_string_unsynchronized("Array bounds check failed. (The attempted index is ", to_standard_error = true);
	write_string_unsynchronized(write_number(index), to_standard_error = true);
	
	if limit > 0
	{
		write_string_unsynchronized(", but the highest valid index is ", to_standard_error = true);
		write_string_unsynchronized(write_number(limit-1), to_standard_error = true);
	}
	else if limit == 0
	{
		write_string_unsynchronized(", but the array has dimension 0, so no index is valid", to_standard_error = true);
	}
	else
	{
		write_string_unsynchronized(", but the array has invalid negative dimension ", to_standard_error = true);
		write_string_unsynchronized(write_number(limit), to_standard_error = true);
	}
	
	write_string_unsynchronized("). Site is ", to_standard_error = true);
	write_string_unsynchronized(to_string(filename), to_standard_error = true);
	write_string_unsynchronized(":", to_standard_error = true);
	write_string_unsynchronized(write_number(line_number), to_standard_error = true);
	write_string_unsynchronized(".\n", to_standard_error = true);
	
	my_panic();
}

__cast_bounds_check_fail :: (pre_value: s64, pre_flags: u32, post_value: s64, post_flags: u32, fatal: u8, line_number: s64, filename: *u8) #no_context
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);
	
	bits : s32 = 0;
	
	NUMBER_FLAG_SIGNED   :: 0x40;
	NUMBER_FLAG_8BIT     :: 0x100;
	NUMBER_FLAG_16BIT    :: 0x200;
	NUMBER_FLAG_32BIT    :: 0x400;
	NUMBER_FLAG_64BIT    :: 0x800;
	
	if post_flags & NUMBER_FLAG_64BIT bits = 64;
	if post_flags & NUMBER_FLAG_32BIT bits = 32;
	if post_flags & NUMBER_FLAG_16BIT bits = 16;
	if post_flags & NUMBER_FLAG_8BIT  bits = 8;
	
	write_string_unsynchronized("Cast bounds check failed.  Number must be in [", to_standard_error = true);
	
	if post_flags & NUMBER_FLAG_SIGNED
	{
		high_value := (1 << (bits - 1)) - 1;
		low_value  := ~high_value;
		write_string_unsynchronized(write_number(low_value), to_standard_error = true);
		write_string_unsynchronized(", ", to_standard_error = true);
		write_string_unsynchronized(write_number(high_value), to_standard_error = true);
	}
	else
	{
		// We don't yet have our stringent definition of left-shift, so, we are generating results
		// that will vary on different machines unless we check. So let's check.
		high_value: u64;
		if bits == 64
		{
			high_value = 0xffff_ffff_ffff_ffff;
		}
		else
		{
			high_value = ((cast(u64)1) << bits) - 1;
		}
		
		write_string_unsynchronized("0, ", to_standard_error = true);
		write_string_unsynchronized(write_number(high_value), to_standard_error = true);
	}
	
	write_string_unsynchronized("]; it was ", to_standard_error = true);
	
	if pre_flags & NUMBER_FLAG_SIGNED
	{
		write_string_unsynchronized(write_number(pre_value), to_standard_error = true);
	}
	else
	{
		write_string_unsynchronized(write_number(cast,no_check(u64) pre_value), to_standard_error = true);
	}
	
	write_string_unsynchronized(".  Site is ", to_standard_error = true);
	
	write_string_unsynchronized(to_string(filename), to_standard_error = true);
	write_string_unsynchronized(":", to_standard_error = true);
	write_string_unsynchronized(write_number(line_number), to_standard_error = true);
	write_string_unsynchronized(".\n", to_standard_error = true);
	
	if fatal my_panic();
}

__null_pointer_check_fail :: (index: s64, line_number: s64, filename: *u8) #no_context
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);

	// @Volatile: It is a good idea for these to match the error reports in constant-expression evaluation inside the compiler.
	if index 
	{
		// This is a procedure argument.
		write_string_unsynchronized("Null pointer check failed: Argument ", to_standard_error = true);
		write_string_unsynchronized(write_number(index), to_standard_error = true);
		write_string_unsynchronized(" is undergoing an automatic dereference, but the pointer is null. Site is ", to_standard_error = true);
	} else {
		// It was a dereference that happened in some other way.
		write_string_unsynchronized("Null pointer check failed: A pointer is undergoing an automatic dereference, but the pointer is null. Site is ", to_standard_error = true);
	}
	
	write_string_unsynchronized(to_string(filename), to_standard_error = true);
	write_string_unsynchronized(":", to_standard_error = true);
	write_string_unsynchronized(write_number(line_number), to_standard_error = true);
	write_string_unsynchronized(".\n", to_standard_error = true);
	
	my_panic();
}

__arithmetic_overflow :: (left: s64, right: s64, type_code: u16, line_number: s64, filename: *u8) #no_context #no_aoc
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);

	// We have some free bits in type_code...!
	fatal  := (type_code & 0x8000);
	signed := (type_code & 0x4000);
	operator_index := (type_code >> 7) & 0x3;
	size := (cast(u64)(type_code & 0x000f))*8;
	
	signed_string := ifx signed then "s" else "u";
	operator_string := " / ";
	
	if      operator_index == 1 then operator_string = " + ";
	else if operator_index == 2 then operator_string = " - ";
	else if operator_index == 3 then operator_string = " * ";
	
	write_string_unsynchronized("Arithmetic overflow. We tried to compute:\n    ", to_standard_error = true);
	
	write_string_unsynchronized(write_number(left), to_standard_error = true);
	write_string_unsynchronized(operator_string, to_standard_error = true);
	write_string_unsynchronized(write_number(right), to_standard_error = true);
	
	write_strings_unsynchronized("\nThe operand type is ", signed_string, to_standard_error = true);
	write_string_unsynchronized(write_number(size), to_standard_error = true);
	write_string_unsynchronized(", but the result does not fit into this type.\n", to_standard_error = true);
	
	if fatal my_panic();
}

write_strings_unsynchronized :: (strings: ..string, to_standard_error := false) #no_context
{
	for strings write_string_unsynchronized(it, to_standard_error);
}

write_string  :: (s: string, to_standard_error := false) #no_context #compiler
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);
	
	write_string_unsynchronized(s, to_standard_error);
}

write_strings :: (strings: ..string, to_standard_error := false) #no_context #compiler
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);
	
	write_strings_unsynchronized(..strings, to_standard_error);
}

// @Volatile: Context_Base must match internal compiler settings in general.h
// It must exist and be relatively easy to compile (without requiring #run of
// procedures, for example). Context_Base is going to be annoying to edit because
// if you make an error of some kind, even a simple one like an undeclared identifier,
// you won't get a helpful error message.
Context_Base :: struct 
{
	context_info:  *Type_Info_Struct; // Allow libs or DLLs to see what context we are passing them. Will always be initialized to type_of(Context).
	
	thread_index   : u32;
	
	allocator      := default_allocator;
	
	logger         := runtime_support_default_logger;
	logger_data    :  *void;
	log_source_identifier: u64;      // Arbitrary identifier; settable by the main program.
	log_level      :  Log_Level;     // Settable by the main program to inform anyone who logs.
	
	temporary_storage: *Temporary_Storage;
	
	// Currently, for simplicity we don't #if this out right now when _STACK_TRACE is false
	// (but may later). It is probably convenient to let runtime code be able
	// to check context.stack_trace to see if it is null in some cases,
	// rather than needing all that to be #iffed as well. We will see.
	stack_trace: *Stack_Trace_Node;
	
	assertion_failed := runtime_support_assertion_failed;
	handling_assertion_failure := false;  // Used to avoid assert() infinite loops. Do not mess with this value.
	
	default_allocator :: Allocator.{runtime_support_default_allocator_proc, null};
}

Temporary_Storage :: struct // @Volatile: Must match general.h
{
	data:     *u8;
	size:     s64;
	current_page_bytes_occupied: s64;
	total_bytes_occupied: s64;
	high_water_mark: s64;
	last_set_mark_location: Source_Code_Location;
	
	overflow_allocator : Allocator;
	
	overflow_pages: *Overflow_Page;
	original_data: *u8;  // Data to restore after clearing overflow pages. @Simplify: Maybe could be an Overflow_Page, but maybe we want to be able to assert on overflow_pages==null to ensure performance.
	original_size: s64;
	
	Overflow_Page :: struct
	{
		next: *Overflow_Page;
		allocator: Allocator;
		size: s64;
	}
}

set_initial_data :: (ts: *Temporary_Storage, count: s64, data: *u8) #no_context
{
	ts.data = data;
	ts.size = count;
	
	ts.original_data = data;
	ts.original_size = count;
}

#if DEFINE_INITIALIZATION 
{
	// TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.
	
	first_thread_context: #Context;
	first_thread_temporary_storage: Temporary_Storage;
	first_thread_temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;
	
	#scope_export
	#program_export
	__jai_runtime_init :: (argc: s32, argv: **u8) -> *#Context #c_call
	{
		__command_line_arguments.count = argc;
		__command_line_arguments.data  = argv;
		
		// We don't need this initializer_of call, but we're leaving it in a comment, in case there are
		// compiler bugs in Context init and you want to work around them by re-enabling it.
		// @Temporary: Putting it back for a bit since there is a bug exhibiting on Mac that might
		// also cause first_thread_context not to be fully filled out...
		initializer_of(#Context)(*first_thread_context);
		
		ts := *first_thread_temporary_storage;
		set_initial_data(ts, TEMPORARY_STORAGE_SIZE, first_thread_temporary_storage_data.data);
		first_thread_context.temporary_storage = ts;
		
		return *first_thread_context;
	}
}

#if DEFINE_SYSTEM_ENTRY_POINT
{
	#program_export "main"
	__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call
	{
		__jai_runtime_init(argc, argv);
		
		push_context first_thread_context
		{
			__program_main :: () #entry_point;
			no_inline __program_main();
		}
		
		return 0;
	}
}

#scope_module

Default_Allocator :: #import "Default_Allocator";

runtime_support_default_allocator_proc :: Default_Allocator.allocator_proc;

write_loc :: (loc: Source_Code_Location, to_standard_error := false) #no_context
{
	write_strings_unsynchronized(loc.fully_pathed_filename, ":", to_standard_error = to_standard_error);
	write_string_unsynchronized(write_number(loc.line_number), to_standard_error);
	write_string_unsynchronized(",", to_standard_error);
	write_string_unsynchronized(write_number(loc.character_number), to_standard_error);
}

my_panic :: () #no_context
{
	write_string_unsynchronized("Panic.\n", to_standard_error = true);
	debug_break();
}

__panic_due_to_runtime_call_of_compile_time_procedure :: (line_number: s64, filename: *u8) #no_context
{
	lock(*CONSOLE_LOCK);
	defer unlock(*CONSOLE_LOCK);

	write_string_unsynchronized("Error: Attempt to call a compile-time procedure at runtime. The location of the call was: ", to_standard_error = true);
	write_string_unsynchronized(to_string(filename), to_standard_error = true);
	write_string_unsynchronized(":", to_standard_error = true);
	write_string_unsynchronized(write_number(line_number), to_standard_error = true);
	write_string_unsynchronized(".\n", to_standard_error = true);
	
	my_panic();
}

#scope_export

Mutex :: struct
{
	value: s64;
}

Semaphore :: struct
{
	value: s64;
}

debug_break :: () #no_context
{
	if #compile_time
	{
		compile_time_debug_break :: () #compiler #no_context;
		compile_time_debug_break();
	}
	else
	{
		wasm_debug_break();
	}
}

sleep :: inline (ms: s32) #no_context
{
	sentinel := 0;

	wasm_sleep(*sentinel, (cast(s64)ms)*1000000);
}

start :: (semaphore: *Semaphore, value: s32 = 1) #no_context
{
	semaphore.value = value;
}

close :: (semaphore: *Semaphore) #no_context
{

}

wake :: inline (semaphore: *Semaphore) #no_context
{
	wasm_wake(*semaphore.value);
}

wait :: inline (semaphore: *Semaphore) #no_context
{
	wasm_wait(*semaphore.value);
}

start :: (mutex: *Mutex) #no_context
{

}

close :: (mutex: *Mutex) #no_context
{

}

lock :: inline (mutex: *Mutex) #no_context
{
	wasm_lock(*mutex.value);
}

unlock :: inline (mutex: *Mutex) #no_context
{
	wasm_unlock(*mutex.value);
}

write_string_unsynchronized :: (s: string, to_standard_error := false) #no_context
{
	wasm_write_string(s.count, s.data, to_standard_error);
}

#scope_file

CONSOLE_LOCK: Mutex;
SYNC_INITTED: s32 = 0;

wasm_debug_break  :: ()                                                 #foreign;
wasm_sleep        :: (address: *s64, ns: s64)                           #foreign;
wasm_wake         :: (address: *s64)                                    #foreign;
wasm_wait         :: (address: *s64)                                    #foreign;
wasm_lock         :: (address: *s64)                                    #foreign;
wasm_unlock       :: (address: *s64)                                    #foreign;
wasm_write_string :: (count: s64, data: *void, to_standard_error: bool) #foreign;
