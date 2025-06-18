
import { prepare_wasm_app } from "/js/common.js";

onmessage = async function(message)
{
	const { index, modules, imports, stack_pointer } = message.data;

    const app = prepare_wasm_app({modules, imports, stack_pointer, wasm_notify_main_thread_flow_initialized});
	app.exports.run_worker_control_flow(BigInt(index));
}

function wasm_notify_main_thread_flow_initialized(){
    postMessage({status:"not so well send help"});
}

