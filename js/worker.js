import { sleep, jaiTojsString, wasmDebugBreak, writeToConsoleLog } from "/js/common.js";

onmessage = async function(message)
{
	const { modules, imports, thread_index} = message.data;
	
	const memory = imports["env"]["memory"];
	
	// TODO: Have this in wasm directly
	function memcmp(lhs, rhs, size)
	{
		// https://discord.com/channels/661732390355337246/1172463903943446548/1256763226847187127
		// https://www.tutorialspoint.com/c_standard_library/c_function_memcmp.htm
		const str1 = jaiTojsString(memory.buffer, lhs, size);
		const str2 = jaiTojsString(memory.buffer, rhs, size);
		if (str1 == str2)    { return  0; }
		if (!(str1 && str2)) { return -1; }
		if (str1 < str2)     { return -1; }
		if (str1 > str2)     { return  1; }
		
		return -1;
	};
	
	function wasmWriteString(count, data, toStandardError)
	{
		const value = jaiTojsString(memory.buffer, data, count);
		writeToConsoleLog(value, toStandardError);
	}
	
	const atomicInstance = new WebAssembly.Instance(modules[0], imports);
	const threadInstance = new WebAssembly.Instance(modules[1],
		{
			env:
			{
				memory: memory,
				wasm_write_string: wasmWriteString,
				wasm_debug_break:  wasmDebugBreak,
				memcmp: memcmp,
				wait:   atomicInstance.exports.wait,
				lock:   atomicInstance.exports.lock,
				unlock: atomicInstance.exports.unlock,
				sleep:  sleep,
			}
		}
	);

	console.log("worker(%d): running", thread_index);
	threadInstance.exports.worker_proc(thread_index);
}
