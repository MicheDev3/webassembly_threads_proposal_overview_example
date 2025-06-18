
import { prepare_wasm_app } from "/js/common.js";
import { GLOBALS } from "/js/globals.js"

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
    dispatchButton.addEventListener('click', dispatchWork);
    closeButton.addEventListener('click', closeThreads);

    load_wasm_binary();
}

function dispatchWork(){

	const isWorkDoneInt = app.exports.check_if_work_done();
	const isWorkDone = Boolean(isWorkDoneInt);
	console.log("isWorkDone:", isWorkDone);
	if (isWorkDone == false) {
		console.log("cannot dispatch, work is not done");
		return;
	}

	app.exports.dispatch_work();
	disableDispatchButton();

	requestAnimationFrame(checkIfWorkIsDone);
}
function closeThreads(){
}

function checkIfWorkIsDone(){
	const isWorkDoneInt = app.exports.check_if_work_done();
	const isWorkDone = Boolean(isWorkDoneInt);

	if(isWorkDone) {
		enableDispatchButton();
		return;
	}

	requestAnimationFrame(checkIfWorkIsDone);
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
		).then ( async (modules) => 
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
				app = prepare_wasm_app(modules, imports, total_stack_size);
				app.exports.init(cpuCountB);
				
				for (let i = 1; i < cpuCount; i++)
				{
					// https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers
					const worker = new Worker("/js/worker.js", { type: "module" });
					new Promise(
						(resolve) =>
						{
							const data = 
							{
								index: i-1,
								modules: [atomicModule, appModule],
								imports: {env: {memory: memory}},
								stack_pointer: total_stack_size - BigInt(i)*stack_size,
							}
							worker.postMessage(data);
							worker.onmessage = (event) => resolve(event.data);
							worker.onerror   = (err)=>console.error(err);
						}
					)
				}
			}
		).catch( (err)     => { console.error(err); } );
	}
	else
	{
		console.error("window.crossOriginIsolated return false. Start the server with ./server_start.sh");
	}
}



