// console.log and console.error always add newlines so we need to buffer the output from write_string
// to simulate a more basic I/O behavior. We’ll flush it after a certain time so that you still
// see the last line if you forget to terminate it with a newline for some reason.
let consoleBuffer = "";
let consoleBufferIsStandardError;
let consoleTimeout;
const FLUSH_CONSOLE_AFTER_MS = 3;

function writeToConsoleLog(str, to_standard_error)
{
	if (consoleBuffer && consoleBufferIsStandardError != to_standard_error)
	{
		flushBuffer();
	}
	
	consoleBufferIsStandardError = to_standard_error;
	const lines = str.split("\n");
	for (let i = 0; i < lines.length - 1; i++)
	{
		consoleBuffer += lines[i];
		flushBuffer();
	}
	
	consoleBuffer += lines[lines.length - 1];
	
	clearTimeout(consoleTimeout);
	if (consoleBuffer)
	{
		consoleTimeout = setTimeout(() => {
			flushBuffer();
		}, FLUSH_CONSOLE_AFTER_MS);
	}
	
	function flushBuffer()
	{
		if (!consoleBuffer) return;
		
		if (consoleBufferIsStandardError)
		{
			console.error(consoleBuffer);
		}
		else
		{
			console.log(consoleBuffer);
		}
		
		consoleBuffer = "";
	}
}

// TODO: Properly understand this
function jaiTojsString(buffer, pointer, length)
{
	const u8 = new Uint8Array(buffer)
	const bytes = u8.subarray(Number(pointer), Number(pointer) + Number(length));
	
	// Create a temporary ArrayBuffer and copy the contents of the shared buffer
	// into it.
	const tempBuffer = new ArrayBuffer(Number(length));
	const tempView = new Uint8Array(tempBuffer);
	tempView.set(bytes);
	
	const decoder = new TextDecoder();
	return decoder.decode(tempBuffer);
}

onmessage = async function(message)
{
	const { modules, imports, worker_index} = message.data;
	
	const atomicModule = modules[0];
	const mainModule   = modules[1];
	
	const memory = imports["env"]["memory"];
	const atomicInstance = new WebAssembly.Instance(atomicModule, imports);
	const mainInstance = new WebAssembly.Instance(mainModule,
		{
			env:
			{
				memory: memory,
				memcmp: (lhs, rhs, size) => 
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
				},
				wasm_write_string: (count, data, toStandardError) =>
				{
					const value = jaiTojsString(memory.buffer, data, count);
					writeToConsoleLog(value, toStandardError);
				},
				wasm_debug_break: () => { debugger },
				wasm_sleep:  atomicInstance.exports.sleep,
				wasm_wake:   atomicInstance.exports.wake,
				wasm_wait:   atomicInstance.exports.wait,
				wasm_lock:   atomicInstance.exports.lock,
				wasm_unlock: atomicInstance.exports.unlock,
			}
		}
	);

	mainInstance.exports.worker_main(BigInt(worker_index));
}

