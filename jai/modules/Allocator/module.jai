#scope_file

_MAIN :ArenaType = .Main;
_TEMP :ArenaType = .Temp;

ArenaType :: enum
{
	Main;
	Temp;
}

MemoryBlock :: struct
{
	main_base: *u8;
	main_size: s64;
	
	temp_base: *u8;
	temp_size: s64;
}

carve_memory_block :: (worker_index: s64, worker_count: s64, worker_memory_size: s64, temp_memory_size: s64) -> MemoryBlock #foreign;

#scope_export

MAIN :: *_MAIN;
TEMP :: *_TEMP;

#add_context allocator_type: *ArenaType = MAIN;

MemoryArena :: struct
{
	base: *u8;
	size: s64;
	used: s64;
}

ArenaAllocator :: struct
{
	main: MemoryArena;
	temp: MemoryArena;
}

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
	
	if #complete mode ==
	{
		case .ALLOCATE;
		{
			arena: *MemoryArena;
			if context.allocator_type ==
			{
				case TEMP; { arena = *allocator.temp; }
				case MAIN; { arena = *allocator.main; }
			}
			
			// TODO: Support alignment
			
			result := arena.base + arena.used;
			arena.used += requested_size;
			
			return result;
		}
		case .FREE;
		{
			arena: *MemoryArena;
			if context.allocator_type ==
			{
				case TEMP; { arena = *allocator.temp; }
				case MAIN; { arena = *allocator.main; }
			}
			
			arena.used = 0;
			
			return null;
		}
		case .RESIZE;
		{
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "Resizing is not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case .STARTUP;
		{
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "Startup are not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case .SHUTDOWN;
		{
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "Shutdown are not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case .THREAD_START; #through;
		case .THREAD_STOP;
		{
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "Threading are not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case .CREATE_HEAP; #through;
		case .DESTROY_HEAP;
		{
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "Heaps are not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case .IS_THIS_YOURS;
		{
			// TODO: Actually support this
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "IS_THIS_YOURS is not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case .CAPS;
		{
			// TODO: Actually support this
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "CAPS is not supported.\n");
			context.handling_assertion_failure = false;
			return null;
		}
		case;
		{
			context.handling_assertion_failure = true;
			context.assertion_failed(#location(), "Invalid or corrupt mode passed to allocator_proc().\n");
			context.handling_assertion_failure = false;
			return null;
		}
	}
}

make_arena_allocator :: (worker_index: s64, worker_count: s64, worker_nr_of_pages: s64, temp_nr_of_pages: s64) -> ArenaAllocator
{
	memory_block := carve_memory_block(worker_index, worker_count, worker_nr_of_pages, temp_nr_of_pages);
	result: ArenaAllocator;
	result.main.base = memory_block.main_base;
	result.main.size = memory_block.main_size;
	result.temp.base = memory_block.temp_base;
	result.temp.size = memory_block.temp_size;
	
	return result;
}
