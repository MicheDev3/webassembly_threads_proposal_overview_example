
/////////////////////////////
// Constants
/////////////////////////////

MAIN :: *_MAIN;
TEMP :: *_TEMP;

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

#scope_file

_MAIN :ArenaType = .Main;
_TEMP :ArenaType = .Temp;

NULL_ARENA: MemoryArena = .{null, -1, -1};

#scope_export

/////////////////////////////


/////////////////////////////
// Enums
/////////////////////////////

#scope_file

ArenaType :: enum
{
	Main;
	Temp;
}

#scope_export

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

#add_context arena_type: *ArenaType = MAIN;

/////////////////////////////


/////////////////////////////
// Macros
/////////////////////////////

PUSH_ALLOCATION_TYPE :: (type: *ArenaType) #expand #no_debug
{
    old_type := context.arena_type;
    context.arena_type = type;
    `defer context.arena_type = old_type;
}

PUSH_ALLOCATION_TYPE :: (type: *ArenaType, code: Code) #expand
{
    PUSH_ALLOCATION_TYPE(type);
    
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
            if context.arena_type ==
			{
				case TEMP; { arena = *allocator.temp; }
				case MAIN; { arena = *allocator.main; }
			}
			
			// TODO: Support alignment
			
			result := arena.base + arena.used;
			arena.used += requested_size;
			assert(arena.used <= arena.size);
			
			return result;
		}
		case .FREE;
		{
			arena: *MemoryArena;
            if context.arena_type ==
			{
				case TEMP; { arena = *allocator.temp; }
				case MAIN; { arena = *allocator.main; }
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

/////////////////////////////


/////////////////////////////
// Platform
/////////////////////////////

#if OS == .WASM
{

#scope_file

MemoryBlock :: struct
{
	main_base: *u8;
	main_size: s64;
	
	temp_base: *u8;
	temp_size: s64;
}

#scope_export

carve_memory_block :: (memory_block_index: s64, memory_block_count: s64, worker_memory_size: s64, temp_memory_size: s64) -> MemoryBlock #foreign;

}
else
{
	// TODO: Support Windows
	#assert false "OS unknown or currently unsupported!";
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#scope_file

#import "Basic";

#scope_export

/////////////////////////////