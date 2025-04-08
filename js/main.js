import { sleep } from "/js/common.js";

async function run(modules)
{
	const memory = new WebAssembly.Memory({initial: 1, maximum: 1, shared: true});

	const imports = {env: {memory: memory}};
	const atomics = new WebAssembly.Instance(modules[0], imports);
	const example = new WebAssembly.Instance(modules[1], imports);
	
	const threadCount = window.navigator.hardwareConcurrency - 1;
	console.log("spawing %d workers", threadCount);
	
	// TODO: Temp for testing
	//{
	var temp = 0;
	//}
	var buffer = new Uint8Array(imports["env"]["memory"].buffer);
	
	var   offset = 0;
	const size   = 16;
	const workers = [];
	for (let i = 0; i < threadCount; i++)
	{
		const context = 
		{
			"thread_index": i,
			"mutex":        offset,
			"semaphore":    offset + (i+1)*8
		};
		
		// TODO: Temp for testing
		//{
		if (i==0) { temp = context["semaphore"]; }
		//}
		
		// NOTE: wait function, for now at least, will always decremeant at the
		// start the semaphore so we need to initialise it as 1 before spawing
		// the worker
		buffer[context["semaphore"]] = 1;
		
		// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
		const worker = new Worker("/js/worker.js", { type: "module" });
		workers.push(
			new Promise(
				(resolve) =>
				{
					worker.postMessage(
						{
							modules: modules,
							imports: imports,
							context: context,
						}
					);
					worker.onmessage = (event) => resolve(event.data);
				}
			)
		);
		
		offset += size;
	}
	
	// TODO: Temp for testing
	//{
	for (let i = 0; i < 4; i++)
	{
		await sleep(5000);
		atomics.exports.wake(temp);
	}
	//}
	
	await Promise.all(workers);
}

async function main()
{
	if (window.crossOriginIsolated)
	{
		const atomicsUri = "/public/atomics.wasm";
		const exampleUri = "/public/example.wasm";
		Promise.all(
			[
				WebAssembly.compileStreaming(fetch(atomicsUri)),
				WebAssembly.compileStreaming(fetch(exampleUri)),
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