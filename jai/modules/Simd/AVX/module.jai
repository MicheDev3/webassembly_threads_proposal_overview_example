
/////////////////////////////
// CONSTANTS
/////////////////////////////

LANES :: 8;

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

Lane :: [LANES]float32;

/////////////////////////////


/////////////////////////////
// Operators
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

make_lane :: inline (value: float32) -> Lane
{
	result: Lane = .[
		value, value, value, value,
		value, value, value, value,
	];
	
	return result;
}

addps :: inline (lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm AVX, AVX2
	{
		movaps snd:, [lhs];
		movaps trd:, [rhs];
		
		addps fst:, snd, trd;
		
		movaps [lhs], fst;
	}
}

addps :: inline (dst: *float, lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm AVX, AVX2
	{
		movaps snd:, [lhs];
		movaps trd:, [rhs];
		
		addps fst:, snd, trd;
		
		movaps [dst], fst;
	}
}

mulps :: inline (lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm AVX, AVX2
	{
		movaps snd:, [lhs];
		movaps trd:, [rhs];
		
		mulps fst:, snd, trd;
		
		movaps [lhs], fst;
	}
}

mulps :: inline (dst: *float, lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm AVX, AVX2
	{
		movaps snd:, [lhs];
		movaps trd:, [rhs];
		
		mulps fst:, snd, trd;
		
		movaps [dst], fst;
	}
}

/////////////////////////////
