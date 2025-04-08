import { sleep } from "/js/common.js";

async function run(modules)
{
	const memory = new WebAssembly.Memory({initial: 1, maximum: 1, shared: true});

	const imports = {env: {memory: memory}};
	const atomics = new WebAssembly.Instance(modules[0], imports);
	const example = new WebAssembly.Instance(modules[1], imports);
	
	const threadCount = window.navigator.hardwareConcurrency - 1;
	console.log("spawing %d workers", threadCount);
	
	const workers = [];
	for (let i = 0; i < threadCount; i++)
	{
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
							thread_index: i,
						}
					);
					worker.onmessage = (event) => resolve(event.data);
				}
			)
		);
	}

	const mutexAddr = 0;
	const tryLockResult = atomics.exports.tryLockMutex(mutexAddr);
	if (tryLockResult) 
	{
		console.log("✅ mutex is locked in main thread");
		await sleep(5000);
		atomics.exports.unlockMutex(mutexAddr);
		console.log("main: unlocked");
	} 
	else
	{
		console.log("❌ mutex is NOT locked in main thread");
	}
	
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