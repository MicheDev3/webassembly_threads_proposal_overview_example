import { atomicsUri, exampleUri, sleep } from "/js/common.js";

async function run(index, modules)
{
	const atomics = modules[0];
	const example = modules[1];
	
	const mutexAddr = 0;
	const lockResult = atomics.instance.exports.lockMutex(mutexAddr);
	console.log("worker %d thread tryLockMutex result:", index, lockResult);
	if(lockResult==undefined)
	{
		console.log("✅ lockResult is undefined in worker, this is fine as we are calling lockMutex, not tryLockMutex");
	}
	console.log("unlocking in 1 second, I added a delay to simulate work being computed...");
	await sleep(1000);
	atomics.instance.exports.unlockMutex(mutexAddr);
	console.log("worker %d: unlocked", index);
}

onmessage = async function(message)
{
	const data = message.data;
	const { memory, index } = data;
	
	const imports = {env: {memory: memory}};
	Promise.all(
		[
			WebAssembly.instantiateStreaming(fetch(atomicsUri), imports),
			WebAssembly.instantiateStreaming(fetch(exampleUri), imports),
		]
	)
	.then ( (modules) => { run(index, modules); } )
	.catch( (err)     => { console.error(err);  } )
	;
}
