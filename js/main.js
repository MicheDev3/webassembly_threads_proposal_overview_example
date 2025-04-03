console.log("jai wasm thread example");


const wasmUrl = '/wasm/example.wasm';

async function loadWasm(){
	if(window.crossOriginIsolated==false){
		console.error('window.crossOriginIsolated return false. Start the server with ./server_start.sh');
	}
	

	const response = await fetch(wasmUrl);
	const moduleBytes = await response.arrayBuffer();

	const memory = new WebAssembly.Memory({initial: 1, maximum: 1, shared: true});
	const worker = new Worker('/js/worker.js');
	const mutexAddr = 0;
	worker.postMessage(memory);
	const imports = {env: {memory: memory}};
	
	const module = await WebAssembly.instantiate(moduleBytes, imports);
	console.log(module);
	const instance = module.instance;
	const tryLockResult = instance.exports.tryLockMutex(mutexAddr);
	if (tryLockResult) {
		console.log('✅ mutex is locked in main thread');
		instance.exports.unlockMutex(mutexAddr);
		console.log('main: unlocked')
	} else {
		console.log('❌ mutex is NOT locked in main thread');
	}
}

loadWasm();