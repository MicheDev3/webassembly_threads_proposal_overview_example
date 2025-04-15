import { sleep } from "/js/common.js";

onmessage = async function(message)
{
	const { module, imports, context} = message.data;
	
	const atomicInstance = new WebAssembly.Instance(module, imports);
	
	const memory = imports["env"]["memory"];
	var data = new Uint8Array(memory.buffer);
	
	console.log("worker(%d): started", context["thread_index"]);
	while (data[context["shouldExitAddress"]] == 0)
	{
		console.log("worker(%d): waiting for work", context["thread_index"]);
		atomicInstance.exports.wait(BigInt(context["semaphoreAddr"]));
		if (data[context["shouldExitAddress"]] != 0)
		{
			break;
		}
		
		console.log("worker(%d): requesting lock", context["thread_index"]);
		atomicInstance.exports.lock(BigInt(context["mutexAddr"]));
		console.log("worker(%d): computing work", context["thread_index"]);
		await sleep(1000);
		atomicInstance.exports.unlock(BigInt(context["mutexAddr"]));
		console.log("worker(%d): unlocked", context["thread_index"]);
	}
	
	console.log("worker(%d): terminated", context["thread_index"]);
}

