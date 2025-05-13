#import "Basic";

MS2NS :: 1000000;

sleep :: (worker: *Worker, ms: s64)
{
	sentinel := 0;
	wasm_sleep(*sentinel, ms*MS2NS);
}

wake :: (worker: *Worker)
{
 	assert(worker.semaphore.* >= 0);

	wasm_wake(worker.semaphore);
}

wait :: (worker: *Worker)
{
 	assert(worker.semaphore.* >= 0);

	wasm_wait(worker.semaphore);
}

lock :: (worker: *Worker)
{
	assert(worker.mutex.* >= 0);

	wasm_lock(worker.mutex);
}

unlock :: (worker: *Worker)
{
	assert(worker.mutex.* >= 0);

	wasm_unlock(worker.mutex);
}

Array :: struct ($T: Type, $S: int)
{
    stored:  s64;
    entries: [S]T;
}

operator *[] :: inline (array: *$A/Array, index: s64) -> *array.T
{
    result := *array.entries[index];

    return result;
}

for_expansion :: (array: *$A/Array, body: Code, flags: For_Flags) #expand
{

POINTER :: cast(bool) (flags & .POINTER);
REVERSE :: cast(bool) (flags & .REVERSE);

// TODO: For now REVERSE is not supported
#assert(REVERSE == false);

    for slot_index: 0..array.stored-1
    {
        `it_index := slot_index;
#if POINTER
{
        `it := *(array.*[slot_index]);
}
else
{
        `it := array.*[slot_index];
}    
    
        #insert body;
    }
}

insert :: inline (array: *$A/Array, index: s64) -> *array.T
{
    result := *(array.*[index]);
    array.stored += 1;
    
    return result;
}

insert :: inline (array: *$A/Array, index: s64, value: array.T)
{
    array.*[index] = value;
    array.stored += 1;
}
