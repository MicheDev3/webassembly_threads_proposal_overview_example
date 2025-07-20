
import { prepare_wasm_app } from "/js/common.js";
import { GLOBALS } from "/js/globals.js";
import { WORKER_REQUEST_TYPE } from "/js/workerControlFlowType.js";

let app;
let dispatchButton;
let closeButton;

document.addEventListener('DOMContentLoaded', onDocumentLoaded);

function onDocumentLoaded(){
    // const startButton = document.getElementById('start-button');
    dispatchButton = document.getElementById('dispatch-button');
    closeButton = document.getElementById('close-button');

    // add events
    // startButton.addEventListener('click', startThreads)
    // dispatchButton.addEventListener('click', dispatchWork);
    closeButton.addEventListener('click', closeThreads);

    load_wasm_binary();
}


function closeThreads(){
}


function disableDispatchButton() {
	dispatchButton.classList.add('disabled');
}

function enableDispatchButton() {
	dispatchButton.classList.remove('disabled');
}

async function load_wasm_binary()
{
	if (window.crossOriginIsolated)
	{
		const atomicUri = "/public/atomic.wasm";
		const appUri    = "/public/app.wasm"  ;
		Promise.all(
			[
				WebAssembly.compileStreaming(fetch(atomicUri)),
				WebAssembly.compileStreaming(fetch(appUri  )),
			]
		).then ( (modules) => 
			{
				const atomicModule = modules[0];
				const appModule    = modules[1];
							
				const memory = new WebAssembly.Memory
				(
					{
						"initial": BigInt(GLOBALS.PAGES_COUNT),
						"maximum": BigInt(GLOBALS.PAGES_COUNT),
						"shared": true,
						"address": "i64"
					}
				);
				
				var cpuCount = window.navigator.hardwareConcurrency;
				if (cpuCount > GLOBALS.CPUS_COUNT) { cpuCount = GLOBALS.CPUS_COUNT; }
				const cpuCountB = BigInt(cpuCount);
	
				const total_stack_size = BigInt(GLOBALS.STACK_SIZE);
				const stack_size = total_stack_size/cpuCountB;
				const imports =  {env: {memory: memory}};

				// create worker for control flow
				const worker = new Worker("/js/workerControlFlow.js", { type: "module" });
				const data =
				{
					modules: [atomicModule, appModule],
					imports: {env: {memory: memory}},
					stack_pointer: total_stack_size,
					type: WORKER_REQUEST_TYPE.INSTANTIATE_WASM,
					cpu_count: cpuCountB
				}
				
				worker.postMessage(data);
				worker.onmessage = (event) => {
					console.log('control flow worker sent event to main thread (we are in main thread)', event);
				}
				worker.onerror   = (err)=>{ console.log('something wrong happened with the worker'); console.error(err); }
				
				dispatchButton.addEventListener('click', ()=>{
					const dispatchData = {
						type:WORKER_REQUEST_TYPE.DISPATCH_WORK
					};
					worker.postMessage(dispatchData);
				});

				// create the workers that will process tasks 				
				for (let i = 1; i < cpuCount; i++)
				{
					// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
					const worker = new Worker("/js/workerTask.js", { type: "module" });
					const data = 
					{
						index: i-1,
						modules: [atomicModule, appModule],
						imports: {env: {memory: memory}},
						stack_pointer: total_stack_size - BigInt(i)*stack_size,
					};
					worker.postMessage(data);
					worker.onmessage = (event) => {
						console.error('task worker sent event to main thread (we are in main thread):', event);
					}
					worker.onerror   = (err)=>{console.log('something wrong happened with the worker');console.error(err);}
				}



			}
		).catch( (err)     => { console.error(err); } );
	}
	else
	{
		console.error("window.crossOriginIsolated return false. Start the server with ./server_start.sh");
	}
}



