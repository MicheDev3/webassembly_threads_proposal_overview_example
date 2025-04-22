import { jaiTojsString, wasmDebugBreak, writeToConsoleLog } from "/js/common.js";

onmessage = async function(message)
{
	const { modules, imports, worker_index} = message.data;
	
	const atomicModule = modules[0];
	const mainModule   = modules[1];
	
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
	
	const atomicInstance = new WebAssembly.Instance(atomicModule, imports);
	const mainInstance = new WebAssembly.Instance(mainModule,
		{
			env:
			{
				memory: memory,
				wasm_write_string: wasmWriteString,
				wasm_debug_break:  wasmDebugBreak,
				memcmp: memcmp,
				sleep:  atomicInstance.exports.sleep,
				wake:   atomicInstance.exports.wake,
				wait:   atomicInstance.exports.wait,
				lock:   atomicInstance.exports.lock,
				unlock: atomicInstance.exports.unlock,
				get_worker_count: ()        => { debugger },
				push_worker: (worker_index) => { debugger },
			}
		}
	);

	mainInstance.exports.worker_main(worker_index);
}
