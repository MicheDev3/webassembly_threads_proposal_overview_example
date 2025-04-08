import { sleep } from "/js/common.js";

onmessage = async function(message)
{
	const data = message.data;
	const { modules, imports, context} = data;
	
	const atomics = new WebAssembly.Instance(modules[0], imports);
	const example = new WebAssembly.Instance(modules[1], imports);
	
	var view = new Uint8Array(imports["env"]["memory"].buffer);
	while (true)
	{
		console.log("worker(%d): waiting for work", context["thread_index"]);
		atomics.exports.wait(context["semaphore"]);

		console.log("worker(%d): requesting lock", context["thread_index"]);
		atomics.exports.lock(context["mutex"]);
		console.log("worker(%d): computing work", context["thread_index"]);
		await sleep(1000);
		atomics.exports.unlock(context["mutex"]);
		console.log("worker(%d): unlocked", context["thread_index"]);
	}
}
