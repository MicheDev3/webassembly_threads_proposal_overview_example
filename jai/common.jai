
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
