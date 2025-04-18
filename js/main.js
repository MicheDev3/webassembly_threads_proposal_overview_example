import { sleep, jaiTojsString, wasmDebugBreak, writeToConsoleLog } from "/js/common.js";

async function run(modules)
{
	const sharedModule = modules[0];
	const atomicModule = modules[1];
	const threadModule = modules[2];
	const mainModule   = modules[3];
	
	const sharedInstance = new WebAssembly.Instance(sharedModule);
	const memory = sharedInstance.exports.memory;
	
	// TODO: Have this in wasm directly
	function memcmp(lhs, rhs, size)
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
	};
	
	function wasmWriteString(count, data, toStandardError)
	{
		const value = jaiTojsString(memory.buffer, data, count);
		writeToConsoleLog(value, toStandardError);
	}
	
	const atomicInstance = new WebAssembly.Instance(atomicModule, {env: {memory: memory}});
	const threadInstance = new WebAssembly.Instance(threadModule,
		{
			env:
			{
				memory: memory,
				wasm_write_string: wasmWriteString,
				wasm_debug_break:  wasmDebugBreak,
				memcmp: memcmp,
				wait:   atomicInstance.exports.wait,
				lock:   atomicInstance.exports.lock,
				unlock: atomicInstance.exports.unlock,
				sleep:  sleep,
			}
		}
	);
	
	const workers  = [];
	const mainInstance = new WebAssembly.Instance(mainModule,
		{
			env:
			{
				memory: memory,
				wasm_write_string: wasmWriteString,
				wasm_debug_break:  wasmDebugBreak,
				memcmp: memcmp,
				sleep:  sleep,
				wake:   atomicInstance.exports.wake,
				get_worker_count: () =>
				{
					const workerCount = window.navigator.hardwareConcurrency - 1;
					
					return BigInt(workerCount);
				},
				push_worker: (thread_index) =>
				{
					// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
					const worker = new Worker("/js/worker.js", { type: "module" });
					workers.push(
						new Promise(
							(resolve) =>
							{
								worker.postMessage(
									{
										modules: [atomicModule, threadModule],
										imports: {env: {memory: memory}},
										thread_index: thread_index,
									}
								);
								worker.onmessage = (event) => resolve(event.data);
							}
						)
					);
				},
				init_workers: threadInstance.exports.init_workers,
			}
		}
	);
	
	mainInstance.exports.main(0, BigInt(0));
	
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
		const sharedUri = "/public/shared.wasm";
		const atomicUri = "/public/atomic.wasm";
		const threadUri = "/public/thread.wasm";
		const mainUri   = "/public/main.wasm"  ;
		Promise.all(
			[
				WebAssembly.compileStreaming(fetch(sharedUri)),
				WebAssembly.compileStreaming(fetch(atomicUri)),
				WebAssembly.compileStreaming(fetch(threadUri)),
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
