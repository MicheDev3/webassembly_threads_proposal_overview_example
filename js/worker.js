const wasmUrl = '/wasm/example.wasm';

onmessage = async function(e) {

    console.log('onmessage',e);
    
    const response = await fetch(wasmUrl);
	const moduleBytes = await response.arrayBuffer();
    const mutexAddr = 0;
    console.log('module fetched', moduleBytes.byteLength);
    
    const memory = e.data;
    const imports = {env: {memory: memory}};
    const module = await WebAssembly.instantiate(moduleBytes, imports);
    const instance = module.instance;
    console.log('worker', {module});
    const lockResult = instance.exports.lockMutex(mutexAddr);
    console.log('worker thread tryLockMutex result:', lockResult);
    if(lockResult==undefined){
        console.log('✅ lockResult is undefined in worker, this is fine as we are calling lockMutex, not tryLockMutex');
    }
    console.log('unlocking in 1 second, I added a delay to simulate work being computed...');
    await sleep(1000);
    instance.exports.unlockMutex(mutexAddr);
    console.log('worker: unlocked');
}

async function sleep(durationInMs){
    return new Promise(resolve=>{
        setTimeout(()=>{
            resolve();
        }, durationInMs);
    })
}