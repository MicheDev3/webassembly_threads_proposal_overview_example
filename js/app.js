
import { prepare_wasm_app } from "/js/common.js";
import { GLOBALS } from "/js/globals.js";
import { WORKER_MESSAGE_TYPE } from "/js/workerControlFlowType.js";

let app;
let dispatchButton;
let closeButton;

document.addEventListener('DOMContentLoaded', onDocumentLoaded);

function onDocumentLoaded(){
    console.log("onDocumentLoaded");
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
				const stack_size = total_stack_size/BigInt(cpuCount);
				const imports =  {
					env: {
						memory: memory
					}
				};
				app = prepare_wasm_app({modules, imports, stack_pointer:total_stack_size});
				app.exports.init(cpuCountB);
				
				let lastStackPointer=-1;
				function workerData(index){
					const data = 
					{
						index,
						modules: [atomicModule, appModule],
						imports: {env: {memory: memory}},
						stack_pointer: total_stack_size - BigInt(index+1)*stack_size,
					}
					if (lastStackPointer > 0 ) {
						const delta = data.stack_pointer-lastStackPointer;
						// console.log(data.index, data.stack_pointer, delta);
					}
					lastStackPointer = data.stack_pointer;
					return data;
				}

				// create worker for control flow
				function createControlFlowWorker(){
					const worker = new Worker("/js/workerControlFlow.js", { type: "module" });
					const data = workerData(0);
					data.type = WORKER_MESSAGE_TYPE.INSTANTIATE_WASM;
					worker.postMessage(data);
					worker.onmessage = (event) => {
						console.log('control flow worker sent event to main thread (we are in main thread)', event);
					}
					worker.onerror   = (err)=>{ console.log('something wrong happened with the worker'); console.error(err); }

					dispatchButton.addEventListener('click', ()=>{
						const dispatchData = {
							type:WORKER_MESSAGE_TYPE.DISPATCH_WORK
						};
						worker.postMessage(dispatchData);
					});
				}
				createControlFlowWorker();

				// create the workers that will process tasks 				
				for (let i = 2; i < cpuCount; i++)
				{
					// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
					const worker = new Worker("/js/workerTask.js", { type: "module" });

					const data = workerData(i-1);
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



