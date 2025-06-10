
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

ListLink :: struct ($T: Type, DOUBLE_LINK: bool)
{
#if type_info(T).type ==
{
	case .STRUCT; using value: T;
	case;               value: T;
}
	next: *ListLink(T, DOUBLE_LINK);
#if DOUBLE_LINK
{
	prev: *ListLink(T, DOUBLE_LINK);
}
	
}

LinkedList :: struct ($T: Type, DOUBLE_LINK: bool = false)
{
	count: s64;
	sentinel: *ListLink(T, DOUBLE_LINK);
}

FreeLinkedList :: struct ($T: Type, DOUBLE_LINK: bool = false)
{
	Link :: ListLink(T, DOUBLE_LINK);
	
	used: LinkedList(T, DOUBLE_LINK);
	free: LinkedList(T, DOUBLE_LINK);
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
	#assert list.DOUBLE_LINK "RESERVE is only supported for doubly linked list";
	
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

PUSH_LOCK :: (mutex: *Mutex) #expand
{
	lock         (mutex);
	`defer unlock(mutex);
}

PUSH_LOCK :: (mutex: *Mutex, code: Code) #expand
{
	PUSH_LOCK(mutex);
	
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

make_list :: inline ($T: Type, $DOUBLE_LINK: bool) -> LinkedList(T, DOUBLE_LINK)
{
	result: LinkedList(T, DOUBLE_LINK);
	result.count = 0;
	result.sentinel = New(ListLink(T, DOUBLE_LINK));
	result.sentinel.next = result.sentinel;
	
	return result;
}

insert :: inline
(
	list: *$L/LinkedList,
	link: *ListLink(list.T, list.DOUBLE_LINK)
)
{

#if list.DOUBLE_LINK
{
	link.next = list.sentinel.next;
	link.prev = list.sentinel;
	
	link.next.prev = link;
	link.prev.next = link;
}
else
{
	link.next = list.sentinel.next;
	list.sentinel.next = link;
}
	
	list.count += 1;
}

insert :: inline
(
	list: *$L/LinkedList,
	value: list.T
) -> *ListLink(list.T, list.DOUBLE_LINK)
{
	result := New(ListLink(list.T, list.DOUBLE_LINK));
	result.value = value;
	
	insert(list, result);
	
	return result;
}

get_head :: inline
(
	list: *$L/LinkedList
) -> *ListLink(list.T, list.DOUBLE_LINK)
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
) -> *ListLink(list.T, list.DOUBLE_LINK)
{
	
#if list.DOUBLE_LINK
{
	result := list.sentinel.prev;
	if result == list.sentinel
	{
		result = null;
	}
}
else
{
	result := list.sentinel.next;
	while true
	{
		if result.next == *list.sentinel
		{
			break;
		}
		
		result = result.next;
	}
	
	if result == *list.sentinel
	{
		result = null;
	}
}
	
	return result;
}

//
// NOTE: FreeLinkedList functions
//

make_free_list :: inline ($T: Type, $DOUBLE_LINK: bool) -> FreeLinkedList(T, DOUBLE_LINK)
{
	result: FreeLinkedList(T, DOUBLE_LINK);
	result.used = make_list(T, DOUBLE_LINK);
	result.free = make_list(T, DOUBLE_LINK);
	
	return result;
}

insert :: inline
(
	list: *$L/FreeLinkedList,
	link: *list.Link
)
{
	insert(*list.used, link);
}

insert :: inline
(
	list: *$L/FreeLinkedList,
	value: list.T
) -> *list.Link
{
	// TODO: Reuse value from free
	result := insert(*list.used, value);
	
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
	sentinel := get_sentinel(list);
	assert(link != sentinel);
	assert(list.used.count > 0);
	
#if list.DOUBLE_LINK
{
	link.prev.next = link.next;
	link.next.prev = link.prev;
	
	link.next = list.free.sentinel.next;
	link.prev = list.free.sentinel;
	
	link.next.prev = link;
	link.prev.next = link;
}
else
{
	prev := list.used.sentinel.next;
	while true
	{
		if prev.next == link
		{
			break;
		}
		
		prev = prev.next;
	}
	
	prev.next = link.next;
	
	link.next = list.free.sentinel.next;
	list.free.sentinel.next = link;
}
	
	list.used.count -= 1;
	list.free.count += 1;
}

delete :: inline
(
	list: *$L/FreeLinkedList,
	head: *list.Link,
	tail: *list.Link,
	count: s64
)
{
	sentinel := get_sentinel(list);
	assert(head != sentinel);
	// assert(tail != sentinel);
	assert(list.used.count > 0);

#if list.DOUBLE_LINK
{
	head.prev.next = tail.next;
	tail.next.prev = head.prev;
	
	head.prev = list.free.sentinel;
	tail.next = list.free.sentinel.next;
	
	head.prev.next = head;
	tail.next.prev = tail;
}
else
{
	list.used.sentinel.next = tail.next;
	
	tail.next = list.free.sentinel.next.next;
	list.free.sentinel.next = head;
}
	
	list.free.count += count;
	list.used.count -= count;
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
