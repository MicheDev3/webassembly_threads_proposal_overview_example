import { sleep } from "/js/common.js";

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

async function run(modules)
{
	const memoryModule = modules[0];
	const atomicModule = modules[1];
	const mainModule   = modules[2];
	
	const memoryInstance = new WebAssembly.Instance(memoryModule);
	const memory = memoryInstance.exports.memory;
	
	// TODO: Properly understand this
	//{
	const decoder = new TextDecoder();
	function jaiTojsString(pointer, length)
	{
		const u8 = new Uint8Array(memory.buffer)
		const bytes = u8.subarray(Number(pointer), Number(pointer) + Number(length));
		
		// Create a temporary ArrayBuffer and copy the contents of the shared buffer
		// into it.
		const tempBuffer = new ArrayBuffer(Number(length));
		const tempView = new Uint8Array(tempBuffer);
		tempView.set(bytes);
		
		return decoder.decode(tempBuffer);
	}
	//}
	
	const atomicInstance = new WebAssembly.Instance(atomicModule, {env: {memory: memory}});
	const mainInstance   = new WebAssembly.Instance(mainModule,
		{
			env:
			{
				memory: memory,
				wasm_write_string: (s_count, s_data, to_standard_error) =>
				{
					const string = jaiTojsString(s_data, s_count);
					writeToConsoleLog(string, to_standard_error);
				},
				wasm_debug_break: () => { debugger; },
				wasm_log_dom: (s_count, s_data, is_error) =>
				{
					const log = document.querySelector("#log");
					const string = jaiTojsString(s_data, s_count);
					const lines = string.split("\n");
					for (let i = 0; i < lines.length; i++)
					{
						const line = lines[i];
						if (!line && i == lines.length - 1) continue; // Don’t create an extra empty line after the last newline
						
						const element = document.createElement("div");
						if (is_error) element.style.color = "#d33";
						element.innerText = line;
						log.appendChild(element);
					}
				},
				// TODO: Have this in wasm directly
				memcmp: (lhs, rhs, size) =>
				{
					// https://discord.com/channels/661732390355337246/1172463903943446548/1256763226847187127
					// https://www.tutorialspoint.com/c_standard_library/c_function_memcmp.htm
					const str1 = jaiTojsString(lhs, size);
					const str2 = jaiTojsString(rhs, size);
					if (str1 == str2)    { return  0; }
					if (!(str1 && str2)) { return -1; }
					if (str1 < str2)     { return -1; }
					if (str1 > str2)     { return  1; }
					
					return -1;
				},
				wake: atomicInstance.exports.wake,
				sleep: sleep,
			}
		}
	);
	
	mainInstance.exports.main(0, BigInt(0));
	
	const threadCount = window.navigator.hardwareConcurrency - 1;
	console.log("spawing %d workers", threadCount);
	
	var data = new Uint8Array(memory.buffer);
	
	var   offset = 8;
	const size   = 16;
	
	const shouldExitAddress = 0;
	// TODO: Save these in some structure
	//{
	const workers  = [];
	const contexts = [];
	//}
	for (let i = 0; i < threadCount; i++)
	{
		const context =
		{
			"shouldExitAddress": shouldExitAddress,
			"thread_index":      i,
			"mutexAddr":         offset,
			"semaphoreAddr":     offset + 8,
		};
		contexts.push(context);
		
		// NOTE: wait function, for now at least, will always decremeant at the
		// start the semaphore so we need to initialise it as 1 before spawing
		// the worker
		// TODO: This is 4 bytes but only updating 1 byte
		data[context["semaphoreAddr"]] = 1;
		
		// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
		const worker = new Worker("/js/worker.js", { type: "module" });
		workers.push(
			new Promise(
				(resolve) =>
				{
					worker.postMessage(
						{
							module: atomicModule,
							imports: {env: {memory: memory}},
							context: context,
						}
					);
					worker.onmessage = (event) => resolve(event.data);
				}
			)
		);
		
		offset += size;
	}
	
	await sleep(1000);
	
	// TODO: Temp for testing
	//{
	for (let i = 0; i < 4; i++)
	{
		var context = contexts[Math.floor(Math.random()*contexts.length)];
		atomicInstance.exports.wake(BigInt(context["semaphoreAddr"]));
		
		await sleep(5000);
	}
	//}
	
	// NOTE: Terminating all workers
	//{
	await sleep(1000);
	data[shouldExitAddress] = 1;
	for (const context of contexts)
	{
		atomicInstance.exports.wake(BigInt(context["semaphoreAddr"]));
	}
	//}
	
	// TODO(mike): Understand how to properly use Promise.all()
	await Promise.all(workers)
	.then(
		(values) =>
		{
		}
	);
}

async function main()
{
	if (window.crossOriginIsolated)
	{
		const memoryUri = "/public/memory.wasm";
		const atomicUri = "/public/atomic.wasm";
		const mainUri   = "/public/main.wasm"  ;
		Promise.all(
			[
				WebAssembly.compileStreaming(fetch(memoryUri)),
				WebAssembly.compileStreaming(fetch(atomicUri)),
				WebAssembly.compileStreaming(fetch(mainUri  )),
			]
		)
		.then ( (modules) => { run(modules);       } )
		.catch( (err)     => { console.error(err); } )
		;
	}
	else
	{
		console.error("window.crossOriginIsolated return false. Start the server with ./server_start.sh");
	}
}

main();
