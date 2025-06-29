
/////////////////////////////
// Structs
/////////////////////////////

Block :: struct ($T: Type)
{
	count: s64;
	data:  *T;
}

Array :: struct ($T: Type, $S: int)
{
	stored:  s64;
	entries: [S]T;
}

Buffer :: struct ($T: Type)
{
	stored: s64;
	entries: Block(T);
}

AlignStructTo :: struct (S: s64, T: Type)
#modify 
{
    tis := cast(*Type_Info)T;
    return tis.type == .STRUCT, "Argument must be a struct.";
} {
    #insert -> string 
    {
        builder: String_Builder;
        info := type_info(T);

		print_to_builder(*builder, "	Base :: struct\n");
		print_to_builder(*builder, "	{\n");
		// TODO: make sure this works for inner union and struct
        for * info.members 
        {
            print_to_builder(*builder, "        %: type_of(T.%);\n", it.name, it.name);  // Use type_of so we don't need to reference the string name of the type.
        }
		print_to_builder(*builder, "	}\n");
        
		print_to_builder(*builder, #string DONE
	DESIRED_SIZE :: #run align_forward(size_of(Base), %);
	
	using base: Base;
#place base;
	_: [DESIRED_SIZE] u8 = ---;
DONE, S
		);
		
		result := builder_to_string(*builder,, temp);
        return result;
    }
}

/////////////////////////////


/////////////////////////////
// Operators
/////////////////////////////

operator *[] :: inline (block: *$B/Block, index: s64) -> *block.T
{
	assert(index < block.count);
	
	result := *(block.data[index]);
	
	return result;
}

operator *[] :: inline (array: *$A/Array, index: s64) -> *array.T
{
	assert(index < array.stored);
	
	result := *(array.entries[index]);
	
	return result;
}

operator *[] :: inline (buffer: *$B/Buffer, index: s64) -> *buffer.T
{
	assert(index < buffer.stored);
	
	result := *(buffer.entries[index]);
	
	return result;
}

/////////////////////////////


/////////////////////////////
// Macros
/////////////////////////////

for_expansion :: (block: *$B/Block, body: Code, flags: For_Flags) #expand
{
	POINTER :: cast(bool) (flags & .POINTER);
	REVERSE :: cast(bool) (flags & .REVERSE);
	
	// TODO: For now REVERSE is not supported
	#assert(REVERSE == false);
	
	for slot_index: 0..block.count-1
	{
		`it_index := slot_index;
#if POINTER
{
		`it := *(block.*[slot_index]);
}
else
{
		`it := block.*[slot_index];
}
		#insert body;
	}
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

for_expansion :: (buffer: *$B/Buffer, body: Code, flags: For_Flags) #expand
{
	
	POINTER :: cast(bool) (flags & .POINTER);
	REVERSE :: cast(bool) (flags & .REVERSE);
	
	// TODO: For now REVERSE is not supported
	#assert(REVERSE == false);
	
	for slot_index: 0..buffer.stored-1
	{
		`it_index := slot_index;
#if POINTER
{
		`it := *(buffer.*[slot_index]);
}
else
{
		`it := buffer.*[slot_index];
}
		
		#insert body;
	}
}

ALLOCATE :: (size: s64) -> *void #expand
{
	result := context.allocator.proc(.ALLOCATE, size, 0, null, context.allocator.data);

	return result;
}

FREE :: (arena: ArenaType) #expand
{
	PUSH_ALLOCATOR_PARAMS(allocation(arena));
	
	context.allocator.proc(.FREE, 0, 0, null, context.allocator.data);
}

SHUTDOWN :: () #expand
{
	context.allocator.proc(.SHUTDOWN, 0, 0, null, context.allocator.data);
}

PUSH_ALLOCATOR :: (allocator: Allocator) #expand #no_debug
{
	old_allocator := context.allocator;
	
	context.allocator = allocator;
	`defer context.allocator = old_allocator;
}

PUSH_LOCK :: (mutex: *Mutex, code: Code) #expand
{
	lock  (mutex);
	#insert code;
	unlock(mutex);
}

KIBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return value*1024;
}

MEBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return KIBIBYTES(value)*1024;
}

GIBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return MEBIBYTES(value)*1024;
}

TEBIBYTES :: (value: s64) -> s64 #expand #no_debug
{
	return GIBIBYTES(value)*1024;
}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

//
// NOTE: Block functions
//

reserve :: inline (block: *$B/Block, count: s64)
{
	block.count = count;
	block.data = ALLOCATE(size_of(block.T)*block.count);
}

//
// NOTE: Array functions
//

insert :: inline (array: *$A/Array) -> *array.T
{
	index := array.stored;
	array.stored += 1;
	
	assert(array.stored <= array.entries.count);
	
	result := *(array.*[index]);
	return result;
}

//
// NOTE: Buffer functions
//

reserve :: inline (buffer: *$B/Buffer, count: s64)
{
	buffer.stored = 0;
	reserve(*buffer.entries, count);
}

insert :: inline (buffer: *$B/Buffer) -> *buffer.T
{
	index := buffer.stored;
	buffer.stored += 1;
	
	assert(buffer.stored <= buffer.entries.count);
	
	result := *(buffer.*[index]);
	return result;
}

delete :: inline (buffer: *$B/Buffer) -> *buffer.T
{
	index := buffer.stored - 1;
	result := *(buffer.*[index]);

	buffer.stored -= 1;
	assert(buffer.stored >= 0);
	return result;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Allocator";
#import "Basic";

/////////////////////////////
