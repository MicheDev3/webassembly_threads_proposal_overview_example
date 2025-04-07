const atomicsUri = '/public/atomics.wasm';
const exampleUri = '/public/example.wasm';

async function main(obj)
{
	const mutexAddr = 0;
	const lockResult = obj.instance.exports.lockMutex(mutexAddr);
	console.log('worker thread tryLockMutex result:', lockResult);
	if(lockResult==undefined)
	{
		console.log('✅ lockResult is undefined in worker, this is fine as we are calling lockMutex, not tryLockMutex');
	}
	console.log('unlocking in 1 second, I added a delay to simulate work being computed...');
	await sleep(1000);
	obj.instance.exports.unlockMutex(mutexAddr);
	console.log('worker: unlocked');
}

async function sleep(durationInMs)
{
    return new Promise
    (
    	resolve =>
		{
			setTimeout(
				() => 
				{
					resolve();
				},
				durationInMs
			);
		}
	)
}

onmessage = async function(e)
{
    console.log('onmessage',e);
    
    const response = await fetch(atomicsUri);
    const imports = {env: {memory: e.data}};
	WebAssembly.instantiateStreaming(response, imports)
	.then(main)
	.catch
	(
		(err) =>
		{
			console.error(err);
		}
	);
}