
import { prepare_wasm_app } from "/js/common.js";
import { WORKER_REQUEST_TYPE, WORKER_RESPONSE_TYPE } from "/js/workerControlFlowType.js";

let FRAME_REQUEST;

onmessage = async function(message)
{
    switch(message.data.type){
        case WORKER_REQUEST_TYPE.INSTANTIATE_WASM: {
            return instantiateWasm(message);
        }
        case WORKER_REQUEST_TYPE.DISPATCH_WORK: {
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
	const { modules, imports, stack_pointer, cpu_count} = message.data;

    app = prepare_wasm_app({modules, imports, stack_pointer});
	app.exports.init(cpu_count);
}

function dispatchWork(message){
    if(app==null){
        console.error('wasm not yet instantiated');
        return;
    }

	console.log('"run_worker_control_flow(DISPATCH_WORK)"');
	const result = app.exports.run_worker_control_flow(WORKER_REQUEST_TYPE.DISPATCH_WORK);
	switch(result){
		case WORKER_RESPONSE_TYPE.WORK_DISPATCHED:{
			FRAME_REQUEST = requestAnimationFrame(checkIfWorkIsDone);
			return;
		}
		default:{
			console.error('something went wrong in "run_worker_control_flow(DISPATCH_WORK)" aborting');
			return;
		}
	}
}

function checkIfWorkIsDone(){
    if(app==null){
        console.error('wasm not yet instantiated');
        return;
    }
    
	const result = app.exports.run_worker_control_flow(WORKER_REQUEST_TYPE.CHECK_IF_DONE);
	switch(result){
		case WORKER_RESPONSE_TYPE.PROCESSING_WORK:{
			FRAME_REQUEST = requestAnimationFrame(checkIfWorkIsDone);
			return;
		}
		case WORKER_RESPONSE_TYPE.WORK_COMPLETED:{
			console.log('work completed');
			return;
		}
		default:{
			console.error('something went wrong in "run_worker_control_flow(CHECK_IF_DONE)" aborting');
			return;
		}
	}
}