
import { prepare_wasm_app } from "/js/common.js";

onmessage = async function(message)
{
	const { index, modules, imports, stack_pointer } = message.data;

	const app = prepare_wasm_app({modules, imports, stack_pointer});
	app.exports.run_worker(BigInt(index));
}
