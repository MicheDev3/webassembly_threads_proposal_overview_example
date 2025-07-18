

/////////////////////////////
// Structs
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

M128 :: [4]f32;
M256 :: [8]f32;

/////////////////////////////


/////////////////////////////
// Operators
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

toM128 :: inline (v0: f32) -> M128
{
	result: M128 = .[v0, v0, v0, v0];
	
	return result;
}

toM128 :: inline
(
	v0: f32 = 0,
	v1: f32 = 0,
	v2: f32 = 0,
	v3: f32 = 0
) -> M128
{
	result: M128 = .[v0, v1, v2, v3];
	
	return result;
}

toM256 :: inline (v0: f32) -> M256
{
	result: M256 = .[v0, v0, v0, v0, v0, v0, v0, v0];
	
	return result;
}

toM256 :: inline
(
	v0: f32 = 0,
	v1: f32 = 0,
	v2: f32 = 0,
	v3: f32 = 0,
	v4: f32 = 0,
	v5: f32 = 0,
	v6: f32 = 0,
	v7: f32 = 0
) -> M256
{
	result: M256 = .[v0, v1, v2, v3, v4, v5, v6, v7];
	
	return result;
}

addps :: inline (lhs: M128, rhs: M128) -> M128 #no_abc #no_aoc
{
	result: M128 = lhs;
	#asm
	{
		addps result, rhs;
	}

	return result;
}

addps :: inline (lhs: M256, rhs: M256) -> M256 #no_abc #no_aoc
{
	result: M256 = ---;
	
	res_data := result.data;
	lhs_data := lhs.data;
	rhs_data := rhs.data;
	#asm AVX, AVX2
	{
		movdqu snd:, [lhs_data];
		movdqu trd:, [rhs_data];
		
		addps fst:, snd, trd;
		
		movdqu [res_data], fst;
	}
	
	return result;
}

mulps :: inline (lhs: M128, rhs: M128) -> M128 #no_abc #no_aoc
{
	result: M128 = lhs;
	#asm
	{
		mulps result, rhs;
	}

	return result;
}

mulps :: inline (lhs: M256, rhs: M256) -> M256 #no_abc #no_aoc
{
	result: M256 = ---;
	
	res_data := result.data;
	lhs_data := lhs.data;
	rhs_data := rhs.data;
	#asm AVX, AVX2
	{
		movdqu snd:, [lhs_data];
		movdqu trd:, [rhs_data];
		
		mulps fst:, snd, trd;
		
		movdqu [res_data], fst;
	}
	
	return result;
}

/////////////////////////////
