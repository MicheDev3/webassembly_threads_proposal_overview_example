
/////////////////////////////
// Enums
/////////////////////////////

WorkType :: enum
{
	Geometry;
}

/////////////////////////////


/////////////////////////////
// Structs
/////////////////////////////

Vector34x :: struct
{
	x: M128;
	y: M128;
	z: M128;
}

Vector38x :: struct
{
	x: M256;
	y: M256;
	z: M256;
}

WorkAvailable :: struct
{
	type: WorkType;
	
	union
	{
		geometry: struct
		{
			using chunk: Geometry;
			amount: float;
		}
	}
}

WorkCompleted :: struct
{
	geometry_\count: s64;
}

Geometry :: struct
{
	positions: Block(Vector3);
	normals:   Block(Vector3);
}

/////////////////////////////


/////////////////////////////
// Operators
/////////////////////////////

operator + :: inline (lhs: Vector34x, rhs: Vector34x) -> Vector34x #no_abc #no_aoc
{
	result: Vector34x = ---;
	result.x = addps(lhs.x, rhs.x);
	result.y = addps(lhs.y, rhs.y);
	result.z = addps(lhs.z, rhs.z);
	
	return result;
}

operator * :: inline (lhs: Vector34x, rhs: Vector34x) -> Vector34x
{
	result: Vector34x = ---;
	result.x = mulps(lhs.x, rhs.x);
	result.y = mulps(lhs.y, rhs.y);
	result.z = mulps(lhs.z, rhs.z);
	
	return result;
}

operator * :: inline (lhs: Vector34x, rhs: M128) -> Vector34x
{
	result: Vector34x = ---;
	result.x = mulps(lhs.x, rhs);
	result.y = mulps(lhs.y, rhs);
	result.z = mulps(lhs.z, rhs);
	
	return result;
}

operator + :: inline (lhs: Vector38x, rhs: Vector38x) -> Vector38x #no_abc #no_aoc
{
	result: Vector38x = ---;
	result.x = addps(lhs.x, rhs.x);
	result.y = addps(lhs.y, rhs.y);
	result.z = addps(lhs.z, rhs.z);
	
	return result;
}

operator * :: inline (lhs: Vector38x, rhs: Vector38x) -> Vector38x
{
	result: Vector38x = ---;
	result.x = mulps(lhs.x, rhs.x);
	result.y = mulps(lhs.y, rhs.y);
	result.z = mulps(lhs.z, rhs.z);
	
	return result;
}

operator * :: inline (lhs: Vector38x, rhs: M256) -> Vector38x
{
	result: Vector38x = ---;
	result.x = mulps(lhs.x, rhs);
	result.y = mulps(lhs.y, rhs);
	result.z = mulps(lhs.z, rhs);
	
	return result;
}

operator == :: inline (lhs: $T/WorkCompleted, rhs: T) -> bool
{
    result := (
        lhs.geometry_\count == rhs.geometry_\count
    );
    
    return result;
}

operator >= :: inline (lhs: $T/WorkCompleted, rhs: T) -> bool
{
    result := (
        lhs.geometry_\count >= rhs.geometry_\count
    );
    
    return result;
}

operator + :: inline (lhs: $T/WorkCompleted, rhs: T) -> T
{
    result: T = ---;
    result.geometry_\count = lhs.geometry_\count + rhs.geometry_\count;
    
    return result;
}

operator += :: inline (lhs: *$T/WorkCompleted, rhs: T)
{
    lhs.geometry_\count += rhs.geometry_\count;
}

/////////////////////////////


/////////////////////////////
// Macros
/////////////////////////////

UPDATE_GEOMETRY :: () #expand
{
	positions := `geometry.positions;
	normals   := `geometry.normals;
#if SIMD
{

#if LANES ==
{
	case 4;
		amount_4x := toM128(`amount);
		iterations := (normals.count / LANES);
		while `count < iterations
		{
			defer `count += 1;
			
			p := positions.data + (`count*LANES);
			n := normals.data   + (`count*LANES);
			
			position_4x := toVector34x(p[0], p[1], p[2], p[3]);
			normal\ _4x := toVector34x(n[0], n[1], n[2], n[3]);
			
			computed := position_4x + (normal_4x*amount_4x);
			
			p[0] = .{computed.x[0], computed.y[0], computed.z[0]};
			p[1] = .{computed.x[1], computed.y[1], computed.z[1]};
			p[2] = .{computed.x[2], computed.y[2], computed.z[2]};
			p[3] = .{computed.x[3], computed.y[3], computed.z[3]};
		}
	case 8;
		// TODO: This now is too slow, reengineer the system to use AVX?
		amount_8x := toM256(`amount);
		iterations := (normals.count / LANES);
		while `count < iterations
		{
			defer `count += 1;
			
			p := positions.data + (`count*LANES);
			n := normals.data   + (`count*LANES);
			
			position_8x := toVector38x(p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]);
			normal\ _8x := toVector38x(n[0], n[1], n[2], n[3], n[4], n[5], n[6], n[7]);
			
			computed := position_8x + (normal_8x*amount_8x);
			
			p[0] = .{computed.x[0], computed.y[0], computed.z[0]};
			p[1] = .{computed.x[1], computed.y[1], computed.z[1]};
			p[2] = .{computed.x[2], computed.y[2], computed.z[2]};
			p[3] = .{computed.x[3], computed.y[3], computed.z[3]};
			p[4] = .{computed.x[4], computed.y[4], computed.z[4]};
			p[5] = .{computed.x[5], computed.y[5], computed.z[5]};
			p[6] = .{computed.x[6], computed.y[6], computed.z[6]};
			p[7] = .{computed.x[7], computed.y[7], computed.z[7]};
		}
	case;
		#assert(false);
}

}		

	for `count*LANES..positions.count-1 
	{
		positions[it] += normals[it]*`amount;
	}
}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

toVector34x :: inline 
(
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	v3: Vector3
) -> Vector34x
{
	result: Vector34x = ---;
	result.x = toM128(v0.x, v1.x, v2.x, v3.x);
	result.y = toM128(v0.y, v1.y, v2.y, v3.y);
	result.z = toM128(v0.z, v1.z, v2.z, v3.z);
	
	return result;
}

toVector38x :: inline
(
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	v3: Vector3,
	v4: Vector3,
	v5: Vector3,
	v6: Vector3,
	v7: Vector3
) -> Vector38x
{
	result: Vector38x = ---;
	result.x = toM256(v0.x, v1.x, v2.x, v3.x, v4.x, v5.x, v6.x, v7.x);
	result.y = toM256(v0.y, v1.y, v2.y, v3.y, v4.y, v5.y, v6.y, v7.y);
	result.z = toM256(v0.z, v1.z, v2.z, v3.z, v4.z, v5.z, v6.z, v7.z);
	
	return result;
}

init_geometry :: (geometries: *Block(Geometry), chunks: s64, points: s64, rest: s64, alignment: s64)
{
	reserve(geometries, chunks);
	for *geometries
	{
		count := ifx rest != 0 && it_index == 0 then points + rest else points;
		reserve(*it.positions, count,, allocation=allocation(.Main, alignment));
		reserve(*it.normals,   count,, allocation=allocation(.Main, alignment));
	}
}

init_geometry :: (geometry: *Geometry, count: s64)
{
	reserve(*geometry.positions, count);
	reserve(*geometry.normals,   count);
}

reset_geometry :: (geometry: *Geometry)
{
	for *geometry.positions { it.* = .{0, 0, 0}; }
	for *geometry.normals   { it.* = .{1, 1, 1}; }
}

push_geometry_work :: (geometries: Block(Geometry), completed: *WorkCompleted, amount: float)
{
	for geometries
	{
		work: WorkAvailable;
		work.type = .Geometry;
		work.geometry.chunk = it;
		work.geometry.amount = amount;
		
		add_work(work, sequentially=true);
	}
	
	completed.geometry_count = geometries.count;
}

check_geometry_work :: (geometries: Block(Geometry), amount: float)
{
	for geometry: geometries
	{
		normals   := geometry.normals;
		positions := geometry.positions;
		for found: positions
		{
			expected := normals[it_index]*amount;
			assert(found == expected);
		}
	}
}

push_geometry_work :: 
(
	geometry: Geometry,
	completed: *WorkCompleted,
	work_count: s64,
	points: s64,
	rest: s64,
	amount: float
)
{
	for 0..work_count-1
	{
		work: WorkAvailable;
		work.type = .Geometry;
		
		count :=  ifx rest != 0 && it == 0 then points + rest else points;
		offset := ifx rest != 0 && it != 0 then (points*it) + rest else (points*it);
		
		work.geometry.chunk.positions = .{count, geometry.positions.data + offset};
		work.geometry.chunk.normals   = .{count, geometry.normals  .data + offset};
		work.geometry.amount = amount;
		
		add_work(work, sequentially=true);
	}
	
	completed.geometry_count = work_count;
}

check_geometry_work :: (geometry: Geometry, amount: float)
{
	for found: geometry.positions
	{
		expected := geometry.normals[it_index]*amount;
		assert(found == expected);
	}
}

process_available_work :: (available: *void)
{
	a := cast(*WorkAvailable) available;
	
	if #complete a.type ==
	{
		case .Geometry;
		{
			geometry := a.geometry;
			
			count  := 0;
			amount := geometry.amount;
			
			UPDATE_GEOMETRY();
		}
	}
}

process_completed_work :: (available: *void, completed: *void)
{
	a := cast(*WorkAvailable) available;
	c := cast(*WorkCompleted) completed;
	
	if #complete a.type ==
	{
		case .Geometry;
		{
			c.geometry_\count += 1;
		}
	}
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Math";

/////////////////////////////
