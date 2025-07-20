
/////////////////////////////
// Constants
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

#scope_file

NULL_ARENA: MemoryArena = .{null, -1, -1, -1};

#scope_export

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

#scope_file

Allocation :: struct
{
	alignment: s64;
}

#scope_export

MemoryArena :: struct
{
	base: *u8;
	size: s64;
	used: s64;
	
	watermark: s64;
}

/////////////////////////////

/////////////////////////////
// Functions
/////////////////////////////

#scope_file

operator == :: inline (lhs: MemoryArena, rhs: MemoryArena) -> bool
{
	result := (
		lhs.base == rhs.base
		&&
		lhs.size == rhs.size
		&&
		lhs.used == rhs.used
	);
	
	return result;
}

#scope_export

/////////////////////////////


/////////////////////////////
// Context
/////////////////////////////

#add_context allocation: Allocation = .{4};

/////////////////////////////


/////////////////////////////
// Macros
/////////////////////////////

PUSH_ALLOCATOR_PARAMS :: (allocation: Allocation) #expand #no_debug
{
	old_allocation := context.allocation;
	context.allocation = allocation;
	`defer context.allocation = old_allocation;
}

PUSH_ALLOCATOR_PARAMS :: (allocation: Allocation, code: Code) #expand
{
	PUSH_ALLOCATOR_PARAMS(allocation);
	
	#insert code;
}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

allocator_proc ::
(
	mode: Allocator_Mode,
	requested_size: s64,
	old_size: s64,
	old_memory: *void,
	allocator_data: *void
) -> *void
{
	arena: *MemoryArena = allocator_data;
	
	if #complete mode ==
	{
		case .ALLOCATE;
		{
			alignment := context.allocation.alignment;
			// NOTE: Makinkg sure alignment is a power of two
			assert((alignment & ~(alignment - 1)) == alignment);
			assert(alignment <= 128);
			
			arena.used = align_forward(arena.used, alignment);
			 
			result := arena.base + arena.used;
			arena.used += align_forward(requested_size, alignment);
			
			assert(arena.used <= arena.size);
			
			return result;
		}
		case .FREE;
		{
			arena.used = 0;
			
			return null;
		}
		case .SHUTDOWN;
		{
			// TODO: Should also release the memory
			arena.* = NULL_ARENA;
			
			return null;
		}
		case .RESIZE;        #through;
		case .STARTUP;       #through;
		case .THREAD_START;  #through;
		case .THREAD_\STOP;  #through;
		case .CREATE_\HEAP;  #through;
		case .DESTROY_HEAP;  #through;
		case .IS_THIS_YOURS; #through; // TODO: Actually support this?
		case .CAPS; 			       // TODO: Actually support this?
		{
			assert(false, "Allocation mode not supported.");
			return null;
		}
		case;
		{
			assert(false, "Invalid or corrupt mode used.");
			return null;
		}
	}
}

allocation :: inline (alignment: s64 = 4) -> Allocation
{
	result: Allocation;
	result.alignment = alignment;
	
	return result;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#scope_file

#import "Basic";

#scope_export

/////////////////////////////
