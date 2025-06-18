
import { prepare_wasm_app } from "/js/common.js";
import { WORKER_MESSAGE_TYPE } from "/js/workerControlFlowType.js";

onmessage = async function(message)
{
    switch(message.data.type){
        case WORKER_MESSAGE_TYPE.INSTANTIATE_WASM: {
            return instantiateWasm(message);
        }
        case WORKER_MESSAGE_TYPE.DISPATCH_WORK: {
            return dispatchWork(message);
        }
        default: {
            console.log(message);
            throw new Error("message.data has no type");
        }
    }
}

let app = null;
function instantiateWasm(message){
	const { index, modules, imports, stack_pointer } = message.data;

    app = prepare_wasm_app({modules, imports, stack_pointer, wasm_notify_main_thread_flow_initialized});
	app.exports.run_worker_control_flow(BigInt(index));
}

function wasm_notify_main_thread_flow_initialized(){
    postMessage({status:"not so well send help"});
}

function dispatchWork(message){
    if(app==null){
        console.error('wasm not yet instantiated');
        return;
    }
    const isWorkDoneInt = app.exports.check_if_work_done();
	const isWorkDone = Boolean(isWorkDoneInt);
	console.log("isWorkDone:", isWorkDone);
	if (isWorkDone == false) {
		console.log("cannot dispatch, work is not done");
		return;
	}

	app.exports.dispatch_work();
	// disableDispatchButton();

	requestAnimationFrame(checkIfWorkIsDone);
}

function checkIfWorkIsDone(){
    if(app==null){
        console.error('wasm not yet instantiated');
        return;
    }
	const isWorkDoneInt = app.exports.check_if_work_done();
	const isWorkDone = Boolean(isWorkDoneInt);
    // console.log({isWorkDone});

	if(isWorkDone) {
		// enableDispatchButton();
		return;
	}

	requestAnimationFrame(checkIfWorkIsDone);
}