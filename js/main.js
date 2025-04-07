console.log("jai wasm thread example");

const atomicsUri = '/public/atomics.wasm';
const exampleUri = '/public/example.wasm';

const sharedMemory = new WebAssembly.Memory({initial: 1, maximum: 1, shared: true});

async function main(modules)
{
	const atomics = modules[0];
	const example = modules[1];
	
	console.log("Atomics:", atomics);
	console.log("Example:", example);
	
	const worker = new Worker('/js/worker.js');
	worker.postMessage(sharedMemory);
	
	const mutexAddr = 0;
	const tryLockResult = atomics.instance.exports.tryLockMutex(mutexAddr);
	if (tryLockResult) 
	{
		console.log('✅ mutex is locked in main thread');
		atomics.instance.exports.unlockMutex(mutexAddr);
		console.log('main: unlocked')
	} 
	else
	{
		console.log('❌ mutex is NOT locked in main thread');
	}
}

async function loadWasm()
{
	if(window.crossOriginIsolated==false)
	{
		console.error('window.crossOriginIsolated return false. Start the server with ./server_start.sh');
	}
		
	const imports = {env: {memory: sharedMemory}};
	Promise.all(
		[
			WebAssembly.instantiateStreaming(fetch(atomicsUri), imports),
			WebAssembly.instantiateStreaming(fetch(exampleUri), imports),
		]
	)
	.then(main)
	.catch(
		(err) => 
		{
			console.error(err);
		}
	);
}

loadWasm();