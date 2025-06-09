
#module_parameters () (LLVM := true);

/////////////////////////////
// Constants
/////////////////////////////

#scope_file

#if LLVM
{

// NOTE(mike): https://llvm.org/docs/LangRef.html#int-memcpy
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

atomic_write :: (lhs: *$T, rhs: T) #no_context
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

atomic_read :: (value: *$T) -> T #no_context
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

atomic_add :: (lhs: *$T, rhs: T) -> T #no_context
#modify { return is_atomic(T); }
{
	result: T = lhs.*;
#asm
{
	lock_xadd?T [lhs], rhs;
}
	
	return result;
}


/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

/////////////////////////////
