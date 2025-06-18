export const WORKER_REQUEST_TYPE = {
    INSTANTIATE_WASM: BigInt(0),
    DISPATCH_WORK:    BigInt(1),
    CHECK_IF_DONE:    BigInt(2),
}

export const WORKER_RESPONSE_TYPE = {
	WORK_DISPATCHED: BigInt(0),
    PROCESSING_WORK: BigInt(1),
    WORK_COMPLETED:  BigInt(2),
}
