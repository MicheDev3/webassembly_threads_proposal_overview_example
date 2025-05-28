
/////////////////////////////
// Constants
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

#scope_file

NULL_ARENA: MemoryArena = .{null, -1, -1};

#scope_export

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

ArenaType :: enum
{
	Main;
	Temp;
}

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

#scope_file

MemoryArena :: struct
{
	base: *u8;
	size: s64;
	used: s64;
}

Allocation :: struct
{
	arena: ArenaType;
	alignment: s64;
}

#scope_export

ArenaAllocator :: struct
{
	main: MemoryArena;
	temp: MemoryArena;
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

#add_context allocation: Allocation = .{.Main, 4};

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
	allocator: *ArenaAllocator = allocator_data;
	assert(allocator.main != NULL_ARENA);
	assert(allocator.temp != NULL_ARENA);
	
	if #complete mode ==
	{
		case .ALLOCATE;
		{
			arena: *MemoryArena;
            if context.allocation.arena ==
			{
				case .Temp; { arena = *allocator.temp; }
				case .Main; { arena = *allocator.main; }
			}

			alignment := context.allocation.alignment;
			// NOTE: Makinkg sure alignment is a power of two
            assert((alignment & ~(alignment - 1)) == alignment);
			assert(alignment <= 128);
			
			result := arena.base + arena.used;
			arena.used += align_forward(requested_size, alignment);
			assert(arena.used <= arena.size);
			
			return result;
		}
		case .FREE;
		{
			arena: *MemoryArena;
            if context.allocation.arena ==
			{
				case .Temp; { arena = *allocator.temp; }
				case .Main; { arena = *allocator.main; }
			}
			
			arena.used = 0;
			
			return null;
		}
		case .SHUTDOWN;
		{
			allocator.main = NULL_ARENA;
			allocator.temp = NULL_ARENA;
			
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

allocation :: inline (arena: ArenaType, alignment: s64 = 4) -> Allocation
{
	result: Allocation;
	result.arena     = arena;
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