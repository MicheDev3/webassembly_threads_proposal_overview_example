async function main()
{
	if (window.crossOriginIsolated)
	{
		const atomicUri = "/public/atomic.wasm";
		const mainUri   = "/public/main.wasm"  ;
		Promise.all(
			[
				WebAssembly.compileStreaming(fetch(atomicUri)),
				WebAssembly.compileStreaming(fetch(mainUri  )),
			]
		)
		.then ( async (modules) => 
		{
			const atomicModule = modules[0];
			const mainModule   = modules[1];
			
			const memory = new WebAssembly.Memory
			(
				{
					"initial": BigInt(100),
					"maximum": BigInt(100),
					"shared": true,
					"address": "i64"
				}
			);
			
			const workers  = [];
			// const workerCount = window.navigator.hardwareConcurrency;
			const workerCount = 2;
			for (let i = 0; i < workerCount; i++)
			{
				// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
				const worker = new Worker("/js/worker.js", { type: "module" });
				workers.push(
					new Promise(
						(resolve) =>
						{
							worker.postMessage(
								{
									modules: [atomicModule, mainModule],
									imports: {env: {memory: memory}},
									worker_index: i,
								}
							);
							worker.onmessage = (event) => resolve(event.data);
							worker.onerror   = reject;
						}
					)
				);
			}
			
			// TODO: Understand why this is not triggered
			await Promise.all(workers)
			.then(function(data)
				{
					console.log("All workers terminated");
				}
			)
			.catch(function(error)
				{
					// something went wrong
				}
			);
		})
		.catch( (err)     => { console.error(err); } )
		;
	}
	else
	{
		console.error("window.crossOriginIsolated return false. Start the server with ./server_start.sh");
	}
}

main();

