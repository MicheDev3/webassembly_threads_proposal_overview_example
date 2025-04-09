import { sleep } from "/js/common.js";

onmessage = async function(message)
{
	const data = message.data;
	const { modules, imports, context} = data;
	
	const atomics = new WebAssembly.Instance(modules[0], imports);
	const example = new WebAssembly.Instance(modules[1], imports);

	console.log("worker(%d): started", context["thread_index"]);

	var buffer = new Uint8Array(imports["env"]["memory"].buffer);

	while (buffer[context["shouldExitAddress"]] == 0)
	{
		console.log("worker(%d): waiting for work", context["thread_index"]);
		atomics.exports.wait(context["semaphoreAddr"]);
		if (buffer[context["shouldExitAddress"]] != 0)
		{
			break;
		}

		console.log("worker(%d): requesting lock", context["thread_index"]);
		atomics.exports.lock(context["mutexAddr"]);
		console.log("worker(%d): computing work", context["thread_index"]);
		await sleep(1000);
		atomics.exports.unlock(context["mutexAddr"]);
		console.log("worker(%d): unlocked", context["thread_index"]);
	}
	
	console.log("worker(%d): terminated", context["thread_index"]);
}

