
MS2NS :: 1000000;

sleep :: (worker: *Worker, ms: s64)
{
	wasm_sleep(worker.sentinel, ms*MS2NS);
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

allocate :: (size: s64) -> *void
{
    result := context.allocator.proc(.ALLOCATE, size, 0, null, context.allocator.data);

    return result;
}

NEW :: ($T: Type, initialized := true) -> *T #expand
{
    memory := allocate(size_of(T));

#if initialized 
{
    ini :: initializer_of(T);

    #if ini  inline ini(memory);
    else     memset(memory, 0, size_of(T));
}

    return cast(*T) memory;
}

advance :: inline (array: *$A/Array, amount: s64) -> s64
{
    result := array.stored;
    array.stored += amount;

    return result;
}

insert :: inline (array: *$A/Array, value: array.T) -> (result: *array.T, index: s64)
{
    index := advance(array, 1);
    array.*[index] = value;
    
    result := *(array.*[index]);
    
    return result, index;
}
