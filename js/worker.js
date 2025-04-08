import { sleep } from "/js/common.js";

onmessage = async function(message)
{
	const data = message.data;
	const { modules, imports, thread_index } = data;
	
	const atomics = new WebAssembly.Instance(modules[0], imports);
	const example = new WebAssembly.Instance(modules[1], imports);
	
	const mutexAddr = 0;
	const lockResult = atomics.exports.lockMutex(mutexAddr);
	console.log("worker(%d) thread tryLockMutex result:", thread_index, lockResult);
	if(lockResult==undefined)
	{
		console.log("✅ lockResult is undefined in worker, this is fine as we are calling lockMutex, not tryLockMutex");
	}
	console.log("unlocking in 1 second, I added a delay to simulate work being computed...");
	await sleep(1000);
	atomics.exports.unlockMutex(mutexAddr);
	console.log("worker(%d): unlocked", thread_index);
}
