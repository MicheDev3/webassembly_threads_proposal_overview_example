// A Jai build file for compiling multithreading wasm applications.

// Since Jai currently only supports compiling to WASM64 (i.e. it requires the "Memory64" extension), you need to enable that feature flag in your browser.
// See https://webassembly.org/roadmap/ for where "Memory64" is available and how you can enable it.

// For more info look at: https://github.com/WebAssembly/tool-conventions

// Thanks to Alexey Kutepov (Tsoding/rexim), Patrik Smělý (SogoCZE), and KujuKuju for figuring out how to compile Jai into WASM.

/////////////////////////////
// Costants
/////////////////////////////

WASM_MEMORY_STACK_SIZE :: #run MEBIBYTES(01);
WASM_MEMORY_PAGE_SIZE  :: #run KIBIBYTES(64);

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
  	
  	(func $sleep (export "sleep")
  		(param $address i64)
  		(param $timeout i64)
	        (drop
	        	(call $wait 
	        		(local.get $address)
					(i64.const 0)
					(local.get $timeout)
	        	)
	    	)
  	)

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
			        		;; TODO: for some reason when multiple threads lock a mutex
			        		;; they aren't all unlock so for now just setting a 5 seconds
			        		;;  wait. Understand why this is happening
			        		(i64.const 5000000)
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

COMMON_JS_FILE_CONTENT :: #string DONE
// console.log and console.error always add newlines so we need to buffer the output from write_string
// to simulate a more basic I/O behavior. We’ll flush it after a certain time so that you still
// see the last line if you forget to terminate it with a newline for some reason.
let consoleBuffer = "";
let consoleBufferIsStandardError;
let consoleTimeout;
const FLUSH_CONSOLE_AFTER_MS = 3;

function writeToConsoleLog(str, to_standard_error)
{
	if (consoleBuffer && consoleBufferIsStandardError != to_standard_error)
	{
		flushBuffer();
	}
	
	consoleBufferIsStandardError = to_standard_error;
	const lines = str.split("\n");
	for (let i = 0; i < lines.length - 1; i++)
	{
		consoleBuffer += lines[i];
		flushBuffer();
	}
	
	consoleBuffer += lines[lines.length - 1];
	
	clearTimeout(consoleTimeout);
	if (consoleBuffer)
	{
		consoleTimeout = setTimeout(() => {
			flushBuffer();
		}, FLUSH_CONSOLE_AFTER_MS);
	}
	
	function flushBuffer()
	{
		if (!consoleBuffer) return;
		
		if (consoleBufferIsStandardError)
		{
			console.error(consoleBuffer);
		}
		else
		{
			console.log(consoleBuffer);
		}
		
		consoleBuffer = "";
	}
}

// TODO: Properly understand this
function jaiTojsString(buffer, pointer, length)
{
	const u8 = new Uint8Array(buffer)
	const bytes = u8.subarray(Number(pointer), Number(pointer) + Number(length));
	
	// Create a temporary ArrayBuffer and copy the contents of the shared buffer
	// into it.
	const tempBuffer = new ArrayBuffer(Number(length));
	const tempView = new Uint8Array(tempBuffer);
	tempView.set(bytes);
	
	const decoder = new TextDecoder();
	return decoder.decode(tempBuffer);
}

export prepare_wasm_app function (modules, imports, stack_pointer)
{
	const memory = imports["env"]["memory"];
	const atomics = new WebAssembly.Instance(modules[0], imports);
	const result  = new WebAssembly.Instance(modules[1],
		{
			env:
			{
				memory: memory,
				memcmp: (lhs, rhs, size) => 
				{
					// https://discord.com/channels/661732390355337246/1172463903943446548/1256763226847187127
					// https://www.tutorialspoint.com/c_standard_library/c_function_memcmp.htm
					const str1 = jaiTojsString(memory.buffer, lhs, size);
					const str2 = jaiTojsString(memory.buffer, rhs, size);
					if (str1 == str2)    { return  0; }
					if (!(str1 && str2)) { return -1; }
					if (str1 < str2)     { return -1; }
					if (str1 > str2)     { return  1; }
					
					return -1;
				},
				wasm_write_string: (count, data, toStandardError) =>
				{
					const value = jaiTojsString(memory.buffer, data, count);
					writeToConsoleLog(value, toStandardError);
				},
				wasm_debug_break: () => { debugger },
				wasm_sleep:  atomics.exports.sleep,
				wasm_wake:   atomics.exports.wake,
				wasm_wait:   atomics.exports.wait,
				wasm_lock:   atomics.exports.lock,
				wasm_unlock: atomics.exports.unlock,
				__stack_pointer: new WebAssembly.Global({ value: "i64", mutable: true }, stack_pointer),
			}
		}
	);
	
	return result;
}

DONE;

APP_JS_FILE_CONTENT :: #string DONE

import { prepare_wasm_app } from "/js/common.js";

async function load_wasm_binary()
{
	if (window.crossOriginIsolated)
	{
		const atomicUri = "/public/atomic.wasm";
		const appUri    = "/public/app.wasm"  ;
		Promise.all(
			[
				WebAssembly.compileStreaming(fetch(atomicUri)),
				WebAssembly.compileStreaming(fetch(appUri  )),
			]
		).then ( async (modules) => 
			{
				const atomicModule = modules[0];
				const appModule    = modules[1];
							
				const memory = new WebAssembly.Memory
				(
					{
						"initial": BigInt(%1),
						"maximum": BigInt(%1),
						"shared": true,
						"address": "i64"
					}
				);
				
				var cpuCount = window.navigator.hardwareConcurrency;
				if (cpuCount > %3) { cpuCount = %3; }
	
				const total_stack_size = BigInt(%2);
				const stack_size = total_stack_size/BigInt(cpuCount);
				const app = prepare_wasm_app(modules, imports, total_stack_size);
				app.exports.init(cpuCount);
				
				for (let i = 1; i < cpuCount; i++)
				{
					// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
					const worker = new Worker("/js/worker.js", { type: "module" });
					new Promise(
						(resolve) =>
						{
							const data = 
							{
								index: i-1,
								modules: [atomicModule, appModule],
								imports: {env: {memory: memory}},
								stack_pointer: total_stack_size - BigInt(i)*stack_size,
							}
							worker.postMessage(data);
							worker.onmessage = (event) => resolve(event.data);
							worker.onerror   = reject;
						}
					)
				}
			}
		).catch( (err)     => { console.error(err); } );
	}
	else
	{
		console.error("window.crossOriginIsolated return false. Start the server with ./server_start.sh");
	}
}

load_wasm_binary();

DONE;

WORKER_JS_FILE_CONTENT :: #string DONE

import { prepare_wasm_app } from "/js/common.js";

onmessage = async function(message)
{
	const { index, modules, imports, stack_pointer } = message.data;

	const app = prepare_wasm_app(modules, imports, stack_pointer);
	app.exports.run_worker(BigInt(index));
}

DONE;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

Platform :: enum
{
	None;

	Wasm;
	Win64;
	Linux;
}

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

Options :: struct
{
	optimise: bool;
	
	cache_line_size:  s64;
	max_thread_count: s64;
	
	cache_line_size  = 64;
	max_thread_count = 32;
}

Win64Options :: struct
{
	main_memory_size:   s64;
	temp_memory_size:   s64;
	thread_memory_size: s64;
	
	main_memory_size   = #run MEBIBYTES(100);
	temp_memory_size   = #run MEBIBYTES(5);
	thread_memory_size = #run MEBIBYTES(10);
}

WasmOptions :: struct
{
	compiler_path: string;
	
	js_\ output_path: string;
	wat_\output_path: string;
	wasm_output_path: string;
	
	main_nr_pages:   s64;
	temp_nr_pages:   s64;
	worker_nr_pages: s64;

	compiler_path   = "wat2wasm";
	
	js_\ output_path = "js";
	wat_\output_path = "wat";
	wasm_output_path = "public";
	
	main_nr_pages   = 1000;
	temp_nr_pages   = 10;
	worker_nr_pages = 20;
}

WatToWasmTarget :: struct
{
	src:   string;
	dst:   string;
	data:  string;
	flags: []string;
}

JsSource :: struct
{
	dst:  string;
	data: string;
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

build_win64 :: (build_parent_options: Build_Options, options: Options, platform_options: Win64Options)
{
	w := compiler_create_workspace("Win64");
	
	build_child_options := get_build_options(w);
	copy_commonly_propagated_fields(build_parent_options, *build_child_options);
	
	build_child_options.backend                     = .LLVM;
	build_child_options.output_executable_name      = "win64";
	build_child_options.runtime_support_definitions = .OMIT;
	
	import_paths: [..]string;
	array_add(*import_paths, tprint("%modules", #filepath));
	for build_child_options.import_path
	{
		array_add(*import_paths, it);
	}
	build_child_options.import_path = import_paths;

	if options.optimise
	{
		set_optimization(*build_child_options, .VERY_OPTIMIZED);
	}
	
	set_build_options(build_child_options, w);
	
	remap_import(w, "*", "Default_Allocator", "Allocator");
	
	compiler_begin_intercept(w);
	
	add_build_file("win64_main.jai", w);
	add_build_string(tprint("THREAD_MEMORY_SIZE :: %;", platform_options.thread_memory_size), w);
	add_build_string(tprint("MAIN_MEMORY_SIZE :: %;", platform_options.main_memory_size), w);
	add_build_string(tprint("TEMP_MEMORY_SIZE :: %;", platform_options.temp_memory_size), w);
	add_build_string(tprint("CACHE_LINE_SIZE :: %;", options.cache_line_size), w);
	add_build_string(tprint("MAX_THREAD_COUNT :: %;", options.max_thread_count), w);
	
	compiler_end_intercept(w);
}

build_wasm :: (build_parent_options: Build_Options, options: Options, platfomr_options: WasmOptions)
{
	w := compiler_create_workspace("Wasm");
	
	build_child_options := get_build_options(w);
	copy_commonly_propagated_fields(build_parent_options, *build_child_options);
	
	build_child_options.output_type                         = .DYNAMIC_LIBRARY;
	build_child_options.backend                             = .LLVM;
	build_child_options.os_target                           = .WASM;
	build_child_options.cpu_target                          = .CUSTOM;
	build_child_options.emit_debug_info                     = .DWARF;
	build_child_options.backtrace_on_crash                  = .OFF; // Runtime_Support_Crash_Handler doesn’t support WASM (yet?)
	build_child_options.output_path                         = platfomr_options.wasm_output_path;
	build_child_options.output_executable_name              = "app";
	build_child_options.runtime_support_definitions         = .OMIT;
	// +bulk-memory: will map "memcpy" to "memory.copy" and "memset" to "memory.fill".
	// +atomics    : necessary for setting "--shared-memory" linker flag.
	// https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md
	build_child_options.llvm_options.target_system_features = "+bulk-memory,+atomics";
	// build_child_options.llvm_options.target_system_features = "+bulk-memory,+atomics,+multimemory,+multivalue";
	// build_child_options.llvm_options.target_system_features = "+bulk-memory,+atomics,+mutable-globals";
	build_child_options.llvm_options.enable_split_modules   = false;
	build_child_options.llvm_options.function_sections      = true; // To get around "LLVM ERROR: section already has a defining function: .text"
	
	import_paths: [..]string;
	array_add(*import_paths, tprint("%modules", #filepath));
	for build_child_options.import_path
	{
		array_add(*import_paths, it);
	}
	build_child_options.import_path = import_paths;
	
	total_memory_size := platfomr_options.main_nr_pages*WASM_MEMORY_PAGE_SIZE;
	if total_memory_size <= WASM_MEMORY_STACK_SIZE
	{
		compiler_report(tprint("'total_memory_size(%)' must be greater than 'WASM_MEMORY_STACK_SIZE(%)'", total_memory_size, WASM_MEMORY_STACK_SIZE));
	}
	
	// TODO: Add an extra padding?
	if platfomr_options.main_nr_pages <= platfomr_options.worker_nr_pages
	{
		compiler_report(tprint("'nr_pages(%)' must be greater than 'worker_nr_of_pages(%)'", total_memory_size, platfomr_options.worker_nr_pages));
	}

	// TODO: Add an extra padding?
	if platfomr_options.worker_nr_pages <= platfomr_options.temp_nr_pages
	{
		compiler_report(tprint("'worker_nr_of_pages(%)' must be greater than 'temp_memory_size(%)'", platfomr_options.worker_nr_pages, platfomr_options.temp_nr_pages));
	}

	// clang -Oz --target=wasm64 -nostdlib -c -o utils.o utils.c
/*
  	(global $__stack_pointer (;0;) (import "env" "__stack_pointer") (mut i64))
*/

	allocator_object_file_path := "modules/Allocator/utils.o";
	build_child_options.additional_linker_arguments = .[
		"--no-entry",
		"--stack-first",
		"-z", tprint("stack-size=%", WASM_MEMORY_STACK_SIZE),
		"--import-memory", // memory will be created statically in the memory.wat file and shared with workers and main thread
		"--shared-memory", // memory must be sharable in order for workers and main thread to work on the same chunk of memory (default behavior is copying from/to worker-main boundaries)
		tprint("--initial-memory=%", total_memory_size), // shared memory is fixed (cannot grow at runtime) so we must specify the initial number pages available
		tprint("--max-memory=%",     total_memory_size), // shared memory is fixed (cannot grow at runtime) so we must specify the maximum number pages available
		"--error-limit=0",
		allocator_object_file_path,
	];
	
	if options.optimise
	{
		// TODO: VERY_OPTIMIZED seems to break things, understand why
		// set_optimization(*build_child_options, .VERY_OPTIMIZED);
		set_optimization(*build_child_options, .OPTIMIZED);
	}
	set_build_options(build_child_options, w);
	
	remap_import(w, "*", "Default_Allocator", "Allocator");
	
	compiler_begin_intercept(w);
	
	add_build_file("wasm_main.jai", w);
	add_build_string(tprint("WORKER_NR_OF_PAGES :: %;", platfomr_options.worker_nr_pages), w);
	add_build_string(tprint("TEMP_NR_OF_PAGES :: %;", platfomr_options.temp_nr_pages), w);
	add_build_string(tprint("CACHE_LINE_SIZE :: %;", options.cache_line_size), w);
	add_build_string(tprint("MAX_THREAD_COUNT :: %;", options.max_thread_count), w);
	
	while true
	{
		message := compiler_wait_for_message();
		if message.kind ==
		{
			case .COMPLETE;
			{
				wat_files: []WatToWasmTarget = .[
					.{
						tprint("%atomic.wat",  platfomr_options.wat_\output_path),
						tprint("%atomic.wasm", platfomr_options.wasm_output_path),
						tprint(WAT_ATOMIC_FILE_CONTENT, platfomr_options.main_nr_pages),
						string.[],
					}
				];
				
				print("\nSelected % memory pages (64Kib per page)\n", platfomr_options.main_nr_pages);
				print("WASM compiler: \"%\"\n", platfomr_options.compiler_path);
				
				for wat_files
				{
					if !write_entire_file(it.src, it.data)
					{
						compiler_report(tprint("Failed to create '%'", it.src));
					}
					
					args: [..]string;
					array_add(*args, platfomr_options.compiler_path);
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
				for wat_files
				{
					print("     - from '%' to '%'\n", it.src, it.dst);
				}
				
				print("Generated js files:\n");
				for JsSource.[
					.{
						tprint("%common.js", platfomr_options.js_\ output_path),
						COMMON_JS_FILE_CONTENT,
					},
					.{
						tprint("%app.js", platfomr_options.js_\ output_path),
						tprint(APP_JS_FILE_CONTENT, platfomr_options.main_nr_pages, WASM_MEMORY_STACK_SIZE, options.max_thread_count)
					},
					.{
						tprint("%worker.js", platfomr_options.js_\ output_path),
						WORKER_JS_FILE_CONTENT,
					}
				]
				{
					if write_entire_file(it.dst, it.data)
					{
						print("     - '%'\n", it.dst);
					}
					else
					{
						compiler_report(tprint("Failed to generate '%'", it.dst));
					}
				}
				
				break;
			}
		}
	}
	
	compiler_end_intercept(w);
}

#run
{
	w := get_current_workspace();
	build_parent_options := get_build_options(w);
	
	platform: Platform = .None;
	options: Options; platform_options: Win64Options; w_options: WasmOptions;

	index: s64;
	args := build_parent_options.compile_time_command_line;
	while index < args.count
	{
		defer index += 1;

		option := args[index];
		if option ==
		{
			case "-optimise";
			{
				options.optimise = true;
			}
			case "-platform";
			{
				index += 1;
				
				if args[index] == 
				{
					case "wasm";  { platform = .Wasm;  }
					case "win64"; { platform = .Win64; }
					case "linux"; { platform = .Linux; }
				}
			}
			case "-wasm-compiler-path";
			{
				index += 1;
				
				w_options.compiler_path = args[index];
			}
			case "-wasm-nr-pages";
			{
				index += 1;
				
				w_options.main_nr_pages = to_integer(args[index]);
			}
			case "-max-thread-count";
			{
				index += 1;
				
				options.max_thread_count = to_integer(args[index]);
			}
			case;
			{
				compiler_report(tprint("Unknown option '%'", option));
			}
		}
	}
	
	_, project_folder := split_from_right(#filepath, "jai");
	if #complete platform == 
	{
		case .None;
		{
			compiler_report("Unset or unknown platform");
		}
		case .Wasm;
		{
			// TODO: At the moment the number of threads, for wasm, must be a power of two.
			// If not unaligned memory access runtime errors will occurs, fix!
			w_options.js_\ output_path = sprint("%js/",     project_folder);
			w_options.wat_\output_path = sprint("%wat/",    project_folder);
			w_options.wasm_output_path = sprint("%public/", project_folder);
			for string.[
				w_options.js_\ output_path,
				w_options.wat_\output_path,
				w_options.wasm_output_path,
			]
			{
				if !make_directory_if_it_does_not_exist(it)
				{
					compiler_report(tprint("Failed to create directory '%'", it));
				}
			}
			
			build_wasm(build_parent_options, options, w_options);
		}
		case .Win64;
		{
			build_win64(build_parent_options, options, platform_options);
		}
		case .Linux;
		{
			compiler_report("Linux currently unsupported");
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
#import "String";

/////////////////////////////
