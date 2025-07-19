
/////////////////////////////
// CONSTANTS
/////////////////////////////

LANES :: 4;

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
	];
	
	return result;
}

addps :: inline (lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm
	{
		movdqu fst:, [lhs];
		movdqu snd:, [rhs];
		
		addps fst, snd;
		
		movdqu [lhs], fst;
	}
}

addps :: inline (dst: *float, lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm
	{
		movdqu fst:, [lhs];
		movdqu snd:, [rhs];
		
		addps fst, snd;
		
		movdqu [dst], fst;
	}
}

mulps :: inline (lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm
	{
		movdqu fst:, [lhs];
		movdqu snd:, [rhs];
		
		mulps fst, snd;
		
		movdqu [lhs], fst;
	}
}

mulps :: inline (dst: *float, lhs: *float, rhs: *float32) #no_abc #no_aoc
{
	#asm
	{
		movdqu snd:, [lhs];
		movdqu trd:, [rhs];
		
		mulps snd, trd;
		
		movdqu [dst], snd;
	}
}

/////////////////////////////
