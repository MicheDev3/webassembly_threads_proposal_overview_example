// TODO: This is a temporary solution for experimenting with SIMD

#assert(OS != .WASM);

LANES :: 4;

M128 :: [LANES]float;

Vector34x :: struct
{
	x: M128;
	y: M128;
	z: M128;
}

toM128 :: inline (value: float) -> M128
{
	result: M128 = .[value, value, value, value];
	
	return result;
}

toM128 :: inline (v0: float, v1: float, v2: float, v3: float) -> M128
{
	result: M128 = .[v0, v1, v2, v3];
	
	return result;
}

toVector34x :: inline (v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> Vector34x
{
	result: Vector34x = ---;
	result.x = toM128(v0.x, v1.x, v2.x, v3.x);
	result.y = toM128(v0.y, v1.y, v2.y, v3.y);
	result.z = toM128(v0.z, v1.z, v2.z, v3.z);
	
	return result;
}

operator + :: inline (lhs: Vector34x, rhs: Vector34x) -> Vector34x #no_abc #no_aoc
{
	result: Vector34x = ---;
	result.x = add(lhs.x, rhs.x);
	result.y = add(lhs.y, rhs.y);
	result.z = add(lhs.z, rhs.z);
	
	return result;
}

operator * :: inline (lhs: Vector34x, rhs: Vector34x) -> Vector34x
{
	result: Vector34x = ---;
	result.x = mul(lhs.x, rhs.x);
	result.y = mul(lhs.y, rhs.y);
	result.z = mul(lhs.z, rhs.z);
	
	return result;
}

operator * :: inline (lhs: Vector34x, rhs: M128) -> Vector34x
{
	result: Vector34x = ---;
	result.x = mul(lhs.x, rhs);
	result.y = mul(lhs.y, rhs);
	result.z = mul(lhs.z, rhs);
	
	return result;
}

add :: inline (lhs: M128, rhs: M128) -> M128 #no_abc #no_aoc
{
	result: M128 = lhs;
	#asm
	{
		addps result, rhs;
	}

	return result;
}

mul :: inline (lhs: M128, rhs: M128) -> M128 #no_abc #no_aoc
{
	result: M128 = lhs;
	#asm
	{
		mulps result, rhs;
	}

	return result;
}

