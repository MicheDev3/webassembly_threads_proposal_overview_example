extern void __heap_base;
extern void __heap_end;

typedef __UINTPTR_TYPE__ ptr;
typedef __SIZE_TYPE__    s64;
typedef __UINT8_TYPE__   u8;

#define PAGE_SIZE 65536

typedef struct
{
	u8* main_base;
	s64 main_size;
	
	u8* temp_base;
	s64 temp_size;
} MemoryBlock;

MemoryBlock carve_memory_block
(
	s64 worker_index,
	s64 worker_count,
	s64 worker_nr_of_pages,
	s64 temp_nr_of_pages
)
{
	ptr heap_base = (ptr)&__heap_base;
	ptr heap_end  = (ptr)&__heap_end;
	s64 total_memory_size  = heap_end - heap_base;
	s64 worker_memory_size = worker_nr_of_pages*PAGE_SIZE;
	s64 temp_memory_size   = temp_nr_of_pages  *PAGE_SIZE;
	
	s64 main_memory_size = total_memory_size - (worker_memory_size*worker_count);
	
	s64 total_size = main_memory_size;
	s64 offset = 0;
	if (worker_index > 0)
	{
		total_size = worker_memory_size;
		offset = main_memory_size + (worker_memory_size*(worker_index-1));
	}
	
	MemoryBlock result;
	result.main_base = (u8*)(heap_base + offset);
	result.main_size = total_size - temp_memory_size;
	result.temp_base = result.main_base + result.main_size;
	result.temp_size = temp_memory_size;
	
	return result;
}
