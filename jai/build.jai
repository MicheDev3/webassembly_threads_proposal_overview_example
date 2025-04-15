// A Jai build file for compiling multithreading wasm applications.

// Since Jai currently only supports compiling to WASM64 (i.e. it requires the "Memory64" extension), you need to enable that feature flag in your browser.
// See https://webassembly.org/roadmap/ for where "Memory64" is available and how you can enable it.

// For more info look at: https://github.com/WebAssembly/tool-conventions

// Thanks to Alexey Kutepov (Tsoding/rexim), Patrik Smělý (SogoCZE), and KujuKuju for figuring out how to compile Jai into WASM.

/////////////////////////////
// Costants
/////////////////////////////

WASM_MEMORY_PAGE_SIZE :: #run KIBIBYTES(64);

// This wat file will define shared elements (like memory) for the workers/main thread
WAT_SHARED_FILE_CONTENT :: #string DONE
(module
	(memory (export "memory") i64 %1 %1 shared)
	
	;; TODO: Implement here memset
)
DONE;

// This wat file will define the atomics operations for multithreading
WAT_ATOMIC_FILE_CONTENT :: #string DONE
(module
  	(import "env" "memory" (memory i64 %1 %1 shared))
  	
  	;; TODO: Inline these functions in the future
	;;(
  	(func $wait
  		(param $address i64)
  		(param $value   i64) ;; value to wait for
  		(param $timeout i64) ;; $timeout=-1 => infinite timeout
  		(result i32)
			;; Wait for the address. memory.atomic.wait32 returns:
			;;   0 => "ok", woken by another agent.
			;;   1 => "not-equal", loaded value != expected value
			;;   2 => "timed-out", the timeout expired
  			(memory.atomic.wait64
	        	(local.get $address)
	          	(local.get $value)
	          	(local.get $timeout)
          	)
  	)
  	
  	(func $notify
  		(param $address i64)
  		(param $value   i32) ;; number of waiters to wake
  		(result i32)
			;; Notify waiters. memory.atomic.notify returns
			;; the numbers of waiters woken
			(memory.atomic.notify
	        	(local.get $address)
	        	(local.get $value)
	        )
  	)
  	;;)

  	;; Wake up a thread for work by signaling their semaphore
  	(func (export "wake")
  		(param $address i64)
  			(drop
				(i64.atomic.rmw.add
  					(local.get $address)
  					(i64.const 1)
  				)
  			)
  			
  			(drop
				(call $notify
					(local.get $address)
					(i32.const 1)
				)
			)
  	)
  	
  	;; Stop a thread indefinitely for work
  	(func (export "wait")
  		(param $address i64)
  			(drop
				(i64.atomic.rmw.sub
  					(local.get $address)
  					(i64.const 1)
  				)
  			)
  			
	        (drop
	        	(call $wait 
	        		(local.get $address)
					(i64.const  0)
					(i64.const -1)
	        	)
	    	)
  	)
  	

  	;; Lock a mutex at the given address, retrying until successful.
  	(func (export "lock") 
  		(param $address i64)
	    	(block $done
	      		(loop $retry
      			    ;; Attempt locking. atomic.rmw.cmpxchg works as follow:
				    ;; - Loads the value at $address.
				    ;; - If it is 0 (unlocked), set it to 1 (locked).
				    ;; - Return the originally loaded value.
				    ;;(
				    	(i64.atomic.rmw.cmpxchg
				      		(local.get $address)
		    		  		(i64.const  0) ;; expected value    (0 => unlocked)
		      				(i64.const  1) ;; replacement value (1 => locked  )
		  				)
	  				    ;; Negates the loaded value to have:
	  				    ;; - If 0 => 1, meaning lock     acquired
	  				    ;; - If 1 => 0, meaning lock NOT acquired
						(i64.eqz)
					;;)
					
					;; Breaks if lock acquired
	        		(br_if $done)

					;; We do not care about the result so we drop it
			        (drop
			        	(call $wait 
			        		(local.get $address)
			        		(i64.const  0)
			        		(i64.const -1)
			        	)
		        	)
					
					;; Try to acquire the lock again.
		        	(br $retry)
	      		)
	    	)
  	)

	;; Unlock a mutex at the given address.
  	(func (export "unlock")
    	(param $address i64)
    		;; Unlock the address by storing 0.
		    (i64.atomic.store
		      	(local.get $address)
		      	(i64.const 0)
	      	)
		
			;; We do not care about the result so we drop it
		    (drop
				(call $notify
		        	(local.get $address)
		        	(i32.const 1)
		        )
	        )
  	)
)
DONE;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

WatToWasmTarget :: struct
{
	src:   string;
	dst:   string;
	data:  string;
	flags: []string;
}

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Macros
/////////////////////////////

KIBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return value*1024;
}

MEBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return KIBIBYTES(value)*1024;
}

GIBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return MEBIBYTES(value)*1024;
}

TEBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return GIBIBYTES(value)*1024;
}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

build_tread ::
(
	parent_options: Build_Options,
	wasm_output_path: string,
	nr_pages: int
) -> bool
{
	result: bool;
	w := compiler_create_workspace("Thread");

	child_options := get_build_options(w);
	copy_commonly_propagated_fields(parent_options, *child_options);
	
	child_options.output_type                         = .EXECUTABLE;
	child_options.backend                             = .LLVM;
	child_options.os_target                           = .WASM;
	child_options.cpu_target                          = .CUSTOM;
	child_options.emit_debug_info                     = .DWARF;
	child_options.backtrace_on_crash                  = .OFF; // Runtime_Support_Crash_Handler doesn’t support WASM (yet?)
	child_options.output_path                         = wasm_output_path;
	child_options.output_executable_name              = "thread";
	// +bulk-memory: will map "memcpy" to "memory.copy" and "memset" to "memory.fill".
	// +atomics    : necessary for setting "--shared-memory" linker flag.
	child_options.llvm_options.target_system_features = "+bulk-memory,+atomics";
	child_options.llvm_options.enable_split_modules   = false;
	child_options.llvm_options.function_sections      = true; // To get around "LLVM ERROR: section already has a defining function: .text"
	
	import_paths: [..]string;
	array_add(*import_paths, tprint("%modules", #filepath));
	for child_options.import_path
	{
		array_add(*import_paths, it);
	}
	child_options.import_path = import_paths;
	
	// This was compiled from https://github.com/wingo/walloc via "clang -Oz --target=wasm64 -nostdlib -c -o walloc.o walloc.c".
	// We should probably port this allocator to Jai instead…
	//  -rluba, 2023-11-15
	walloc_object_file_path := "modules/Walloc/walloc.o";
	memory_size := nr_pages*WASM_MEMORY_PAGE_SIZE;
	child_options.additional_linker_arguments = .[
		"--import-memory", // memory will be created statically in the memory.wat file and shared with workers and main thread
		"--shared-memory", // memory must be sharable in order for workers and main thread to work on the same chunk of memory (default behavior is copying from/to worker-main boundaries)
		tprint("--initial-memory=%", memory_size), // shared memory is fixed (cannot grow at runtime) so we must specify the initial number pages available
		tprint("--max-memory=%",     memory_size), // shared memory is fixed (cannot grow at runtime) so we must specify the maximum number pages available
		walloc_object_file_path
	];
	
	set_build_options(child_options, w);
	// Replace the default allocator with Walloc (https://github.com/wingo/walloc).
	remap_import(w, "*", "Default_Allocator", "Walloc");
	
	compiler_begin_intercept(w);

	add_build_file("thread.jai", w);
	
	while true
	{
		message := compiler_wait_for_message();
		if message.kind ==
		{
			case .COMPLETE;
			{
				result = true;
				break;
			}
		}
	}
	
	compiler_end_intercept(w);
	
	return result;
}

build_main ::
(
	parent_options: Build_Options,
	wasm_compiler_path: string,
	wat_output_path: string,
	wasm_output_path: string,
	nr_pages: int
) -> bool
{
	result: bool;

	w := compiler_create_workspace("Main");
	
	child_options := get_build_options(w);
	copy_commonly_propagated_fields(parent_options, *child_options);
	
	child_options.output_type                         = .EXECUTABLE;
	child_options.backend                             = .LLVM;
	child_options.os_target                           = .WASM;
	child_options.cpu_target                          = .CUSTOM;
	child_options.emit_debug_info                     = .DWARF;
	child_options.backtrace_on_crash                  = .OFF; // Runtime_Support_Crash_Handler doesn’t support WASM (yet?)
	child_options.output_path                         = wasm_output_path;
	child_options.output_executable_name              = "main";
	// +bulk-memory: will map "memcpy" to "memory.copy" and "memset" to "memory.fill".
	// +atomics    : necessary for setting "--shared-memory" linker flag.
	child_options.llvm_options.target_system_features = "+bulk-memory,+atomics";
	child_options.llvm_options.enable_split_modules   = false;
	child_options.llvm_options.function_sections      = true; // To get around "LLVM ERROR: section already has a defining function: .text"
	
	import_paths: [..]string;
	array_add(*import_paths, tprint("%modules", #filepath));
	for child_options.import_path
	{
		array_add(*import_paths, it);
	}
	child_options.import_path = import_paths;
	
	// This was compiled from https://github.com/wingo/walloc via "clang -Oz --target=wasm64 -nostdlib -c -o walloc.o walloc.c".
	// We should probably port this allocator to Jai instead…
	//  -rluba, 2023-11-15
	walloc_object_file_path := "modules/Walloc/walloc.o";
	memory_size := nr_pages*WASM_MEMORY_PAGE_SIZE;
	child_options.additional_linker_arguments = .[
		"--import-memory", // memory will be created statically in the memory.wat file and shared with workers and main thread
		"--shared-memory", // memory must be sharable in order for workers and main thread to work on the same chunk of memory (default behavior is copying from/to worker-main boundaries)
		tprint("--initial-memory=%", memory_size), // shared memory is fixed (cannot grow at runtime) so we must specify the initial number pages available
		tprint("--max-memory=%",     memory_size), // shared memory is fixed (cannot grow at runtime) so we must specify the maximum number pages available
		walloc_object_file_path
	];
	
	set_build_options(child_options, w);
	// Replace the default allocator with Walloc (https://github.com/wingo/walloc).
	remap_import(w, "*", "Default_Allocator", "Walloc");
	
	compiler_begin_intercept(w);
	
	add_build_file("main.jai", w);
	
	while true
	{
		message := compiler_wait_for_message();
		if message.kind ==
		{
			case .COMPLETE;
			{
				result = true;
				
				break;
			}
		}
	}
	
	compiler_end_intercept(w);
	
	return result;
}

#run
{
	w := get_current_workspace();
	parent_options := get_build_options(w);
	
	wat_output_path := "../wat/";
	wasm_output_path := "../public/";
	for string.[wat_output_path, wasm_output_path]
	{
		if !make_directory_if_it_does_not_exist(it)
		{
			compiler_report(tprint("Failed to create directory '%'", it));
		}
	}
	
	nr_pages := 100;
	wasm_compiler_path := "wat2wasm";
	args := parent_options.compile_time_command_line;
	for args
	{
		if it_index ==
		{
			case 0; { wasm_compiler_path = it;   }
			case 1; { nr_pages = to_integer(it); }
		}
	}
	
	result: bool;
	result = build_tread(parent_options, wasm_output_path, nr_pages);
	result = build_main(parent_options, wasm_compiler_path, wat_output_path, wasm_output_path, nr_pages);
	
	if result
	{
		files: []WatToWasmTarget = .[
			.{
				tprint("%/shared.wat", wat_output_path),
				tprint("%/shared.wasm", wasm_output_path),
				tprint(WAT_SHARED_FILE_CONTENT, nr_pages),
				string.[],
			},
			.{
				tprint("%/atomic.wat", wat_output_path),
				tprint("%/atomic.wasm", wasm_output_path),
				tprint(WAT_ATOMIC_FILE_CONTENT, nr_pages),
				string.[],
			}
		];
		
		print("\nSelected % (64Kib) memory pages\n", nr_pages);
		print("WASM compiler: \"%\"\n", wasm_compiler_path);
		
		for files
		{
			if !write_entire_file(it.src, it.data)
			{
				compiler_report(tprint("Failed to create '%'", it.src));
			}
			
			args: [..]string;
			array_add(*args, wasm_compiler_path);
			array_add(*args, "--enable-threads");
			array_add(*args, "--enable-memory64");
			for flag: it.flags { array_add(*args, flag); }
			array_add(*args, it.src);
			array_add(*args, "-o");
			array_add(*args, it.dst);
			
			result, output_string, error_string, _ := run_command(..args);
			if result.exit_code != 0
			{
				compiler_report(tprint("Failed to compile '%' error: %", it.src, error_string));
			}
		}
		
		print("Generated and compiled wat files:\n");
		for files
		{
			print("     - from '%' to '%'\n", it.src, it.dst);
		}
	}
				
	set_build_options_dc(.{do_output = false}, w);
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Basic";

#import "Compiler";
#import "File";
#import "Process";

/////////////////////////////
