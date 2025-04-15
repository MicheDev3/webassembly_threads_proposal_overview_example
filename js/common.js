export async function sleep(durationInMs)
{
    return new Promise(
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
	);
}

// TODO: Properly understand this
export function jaiTojsString(buffer, pointer, length)
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

export function wasmDebugBreak()
{
	debugger;
}

// console.log and console.error always add newlines so we need to buffer the output from write_string
// to simulate a more basic I/O behavior. We’ll flush it after a certain time so that you still
// see the last line if you forget to terminate it with a newline for some reason.
let consoleBuffer = "";
let consoleBufferIsStandardError;
let consoleTimeout;
const FLUSH_CONSOLE_AFTER_MS = 3;

export function writeToConsoleLog(str, to_standard_error)
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

