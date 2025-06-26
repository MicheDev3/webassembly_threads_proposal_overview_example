
/////////////////////////////
// Structs
/////////////////////////////

Block :: struct ($T: Type)
{
	count: s64;
	entries: *T;
}

Array :: struct ($T: Type, $S: int = 0)
{
	stored:  s64;
	entries: [S]T;
}

ListLink :: struct ($T: Type)
{
#if type_info(T).type ==
{
	case .STRUCT; using value: T;
	case;               value: T;
}
	next: *ListLink(T);
	prev: *ListLink(T);	
}

LinkedList :: struct ($T: Type)
{
	Link :: ListLink(T);
	
	count: s64;
	sentinel: *Link;
}

FreeLinkedList :: struct ($T: Type)
{
	Link :: ListLink(T);
	
	used: LinkedList(T);
	free: LinkedList(T);
}

/////////////////////////////


/////////////////////////////
// Operators
/////////////////////////////

operator *[] :: inline (block: *$B/Block, index: s64) -> *block.T
{
	assert(index < block.count);
	
	result := *(block.entries[index]);
	
	return result;
}

operator *[] :: inline (array: *$A/Array, index: s64) -> *array.T
{
	assert(index < array.stored);
	
	result := *(array.entries[index]);
	
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

for_expansion :: (list: *$L/LinkedList, body: Code, flags: For_Flags) #expand
{
	POINTER :: cast(bool) (flags & .POINTER);
	REVERSE :: cast(bool) (flags & .REVERSE);
	
	// TODO: Does it really make sense to assert POINTER == true?
	#assert(POINTER == true);
	
#if REVERSE
{
	index := list.count-1;
	link := list.sentinel.prev;
}
else
{
	index: s64;
	link := list.sentinel.next;
}
	
	while link != list.sentinel
	{
		`it_index := index;
		`it := *link.value;
		
		#insert body;
		
#if REVERSE
{
		index -= 1;
		link = link.prev;
}
else
{
		index += 1;
		link = link.next;
}
		
	}
}


for_expansion :: (list: *$L/FreeLinkedList, body: Code, flags: For_Flags) #expand
{
POINTER :: cast(bool) (flags & .POINTER);
REVERSE :: cast(bool) (flags & .REVERSE);

#if REVERSE
{
    for *<`it, `it_index: list.used
    {
        #insert body;
    }
}
else
{
    for *`it, `it_index: list.used
    {
        #insert body;
    }
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
	lock        (mutex);
	defer unlock(mutex);
	
	#insert code;
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
	block.entries = ALLOCATE(size_of(block.T)*block.count);
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
// NOTE: LinkedList functions
//

make_list :: inline ($T: Type) -> LinkedList(T)
{
	result: LinkedList(T);
	result.count = 0;
	result.sentinel = New(ListLink(T));
	result.sentinel.next = result.sentinel;
	result.sentinel.prev = result.sentinel;
	
	return result;
}

enchain :: inline
(
	list: *$L/LinkedList,
	link: *list.Link
)
{
	link.next = list.sentinel.next;
	link.prev = list.sentinel;
	
	link.next.prev = link;
	link.prev.next = link;
	
	list.count += 1;

	assert(link.next != null);
	assert(link.prev != null);
}

enchain :: inline
(
	list: *$L/LinkedList,
	head: *list.Link,
	tail: *list.Link,
	count: s64
)
{
	assert(head != list.sentinel);
	assert(tail != list.sentinel);
	
	tail.next = list.sentinel.next;
	head.prev = list.sentinel;
	
	tail.next.prev = tail;
	head.prev.next = head;

	list.count += count;
}

unchain :: inline
(
	list: *$L/LinkedList,
	link: *list.Link
)
{
	assert(list.count > 0);
	assert(link != list.sentinel);

	link.prev.next = link.next;
	link.next.prev = link.prev;
	
	link.next = null;
	link.prev = null;
	
	list.count -= 1;
}

unchain :: inline
(
	list: *$L/LinkedList,
	head: *list.Link,
	tail: *list.Link,
	count: s64
)
{
	assert(list.count > 0);
	assert(tail != list.sentinel);
	assert(head != list.sentinel);

	head.prev.next = tail.next;
	tail.next.prev = head.prev;
	
	head.prev = null;
	tail.next = null;
	
	list.count -= count;
}

insert :: inline
(
	list: *$L/LinkedList,
	value: list.T
) -> *list.Link
{
	result := New(list.Link);
	result.value = value;
	
	enchain(list, result);
	
	return result;
}

get_head :: inline
(
	list: *$L/LinkedList
) -> *list.Link
{
	result := list.sentinel.next;
	if result == list.sentinel
	{
		result = null;
	}
	
	return result;
}

get_tail :: inline
(
	list: *$L/LinkedList
) -> *list.Link
{
	result := list.sentinel.prev;
	if result == list.sentinel
	{
		result = null;
	}
	
	return result;
}

//
// NOTE: FreeLinkedList functions
//

make_free_list :: inline ($T: Type) -> FreeLinkedList(T)
{
	result: FreeLinkedList(T);
	result.used = make_list(T);
	result.free = make_list(T);
	
	return result;
}

enchain :: inline
(
	list: *$L/FreeLinkedList,
	head: *list.Link,
	tail: *list.Link,
	count: s64
)
{
	enchain(*list.free, head, tail, count);
}

unchain :: inline
(
	list: *$L/FreeLinkedList,
	head: *list.Link,
	tail: *list.Link,
	count: s64
)
{
	unchain(*list.used, head, tail, count);
}

insert :: inline
(
	list: *$L/FreeLinkedList,
	value: list.T
) -> *list.Link
{
	result := list.free.sentinel.next;
	if result == list.free.sentinel
	{
		assert(list.free.count == 0);
		result = insert(*list.used, value);
	}
	else
	{
		unchain(*list.free, result);
		enchain(*list.used, result);
		result.value = value;
	}
	
	return result;
}

get_head :: inline
(
	list: *$L/FreeLinkedList
) -> *list.Link
{
	result := get_head(*list.used);
	
	return result;
}

get_tail :: inline
(
	list: *$L/FreeLinkedList
) -> *list.Link
{
	result := get_tail(*list.used);
	
	return result;
}

delete :: inline
(
	list: *$L/FreeLinkedList,
	link: *list.Link
)
{
	unchain(*list.used, link);
	enchain(*list.free, link);
}

get_count :: inline (list: *$L/FreeLinkedList) -> s64
{
	result := list.used.count;
	
	return result;
}

get_sentinel :: inline (list: *$L/FreeLinkedList) -> *list.Link
{
	result := list.used.sentinel;
	
	return result;
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Allocator";
#import "Basic";

/////////////////////////////
