/*
	Improvements:
		- The MutexTicket seems not yet 100% correct (maybe I need fences?). Keep testing
*/

#module_parameters () (
	LLVM: bool = true
);

/////////////////////////////
// Constants
/////////////////////////////

#scope_file

#if LLVM
{

atomic_memcpy_i32 :: (dst: *void, src: *void, len: s64, is_volatile: bool) #intrinsic "llvm.memcpy.inline.p0.p0.i32";
atomic_memcpy_i64 :: (dst: *void, src: *void, len: s64, is_volatile: bool) #intrinsic "llvm.memcpy.inline.p0.p0.i64";

}
else
{

atomic_memcpy_i32 :: (dst: *void, src: *void, len: s64, is_volatile: bool) #no_context
{
	memcpy(dst, src, len);
}

atomic_memcpy_i64 :: (dst: *void, src: *void, len: s64, is_volatile: bool) #no_context
{
	memcpy(dst, src, len);
}

}

#scope_export

/////////////////////////////


/////////////////////////////
// Globals
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

Mutex :: struct
{
    ticket:  u64;
    serving: u64;
}

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

#scope_file

is_atomic :: (T: Type) -> bool #compile_time
{
    info := cast(*Type_Info)T;
    while info.type == .VARIANT 
    {
        variant := cast(*Type_Info_Variant)info;
        info = variant.variant_of;
    }

    if info.type ==
    {
        case .ENUM;    #through;
        case .INTEGER; #through;
        case .POINTER;
        {
            return true;
        }
    }
    
    return false;
}

#scope_export

atomic_write :: inline (lhs: *$T, rhs: T) #no_context
#modify { return is_atomic(T); }
{
	size :: size_of(T);
	#if size ==
	{
		case 4; { atomic_memcpy_i32(lhs, *rhs, size, true); }
		case 8; { atomic_memcpy_i64(lhs, *rhs, size, true); }
		case;   { #assert(false, "Invalid size"); }
	}
}

atomic_read :: inline (value: *$T) -> T #no_context
#modify { return is_atomic(T); }
{
	result: T;
	size :: size_of(T);
	#if size ==
	{
		case 4; { atomic_memcpy_i32(*result, value, size, true); }
		case 8; { atomic_memcpy_i64(*result, value, size, true); }
		case;   { #assert(false, "Invalid size"); }
	}

	return result;
}

atomic_add :: inline (lhs: *$T, rhs: T) -> T #no_context
#modify { return is_atomic(T); }
{

#asm
{
	lock_xadd?T [lhs], rhs;
}
	
	result: T = rhs;
	return result;
}

initialize_critical_section :: inline (mutex: *Mutex) #no_context
{
	mutex.* = .{};
}

delete_critical_section :: inline (mutex: *Mutex) #no_context
{

}

enter_critical_section :: inline (mutex: *Mutex) #no_context
{
	ticket := atomic_add(*mutex.ticket, 1);
	while ticket != atomic_read(*mutex.serving)
	{
		#asm { pause; }
	}
}

leave_critical_section :: inline (mutex: *Mutex) #no_context
{
	atomic_add(*mutex.serving, 1);
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

/////////////////////////////
