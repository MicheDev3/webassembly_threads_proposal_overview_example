import { atomicsUri, exampleUri, sleep } from "/js/common.js";

async function run(memory, modules)
{
	const atomics = modules[0];
	const example = modules[1];
	
	const workers = [];
	// TODO: Get number of workers based on the number of cores in the machine
	for (let i = 0; i < 4; i++)
	{
		const worker = new Worker("/js/worker.js", { type: "module" });
		workers.push(
			new Promise(
				(resolve) =>
				{
					worker.postMessage({memory, index: i});
					worker.onmessage = (event) => resolve(event.data);
				}
			)
		);
	}

	const mutexAddr = 0;
	const tryLockResult = atomics.instance.exports.tryLockMutex(mutexAddr);
	if (tryLockResult) 
	{
		console.log("✅ mutex is locked in main thread");
		await sleep(5000);
		atomics.instance.exports.unlockMutex(mutexAddr);
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
		const memory = new WebAssembly.Memory({initial: 1, maximum: 1, shared: true});

		const imports = {env: {memory: memory}};
		Promise.all(
			[
				WebAssembly.instantiateStreaming(fetch(atomicsUri), imports),
				WebAssembly.instantiateStreaming(fetch(exampleUri), imports),
			]
		)
		.then ( (modules) => { run(memory, modules); } )
		.catch( (err)     => { console.error(err);   } )
		;
	}
	else
	{
		console.error("window.crossOriginIsolated return false. Start the server with ./server_start.sh");
	}
}

main();