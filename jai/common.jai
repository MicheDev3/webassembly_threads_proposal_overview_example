
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

Vector :: struct
{
	x: Block(f32);
	y: Block(f32);
	z: Block(f32);
}

Geometry :: struct
{
	p: Vector;
	n: Vector;
	
	count: s64;
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

#if SIMD
{
	a := make_lane(`amount);
	
	count: s64;
	offset := (count*LANES);
	iterations := (`geometry.count / LANES);
	while count < iterations
	{		
		px: Lane = ---; py: Lane = ---; pz: Lane = ---;

		mulps(px.data, `geometry.n.x.data + offset, a.data);
		mulps(py.data, `geometry.n.y.data + offset, a.data);
		mulps(pz.data, `geometry.n.z.data + offset, a.data);

		addps(`geometry.p.x.data + offset, px.data);
		addps(`geometry.p.y.data + offset, py.data);
		addps(`geometry.p.z.data + offset, pz.data);
		
		count += 1;
		offset = (count*LANES);
	}

	for count*LANES..`geometry.count-1
	{
		`geometry.p.x[it] = `geometry.n.x[it]*`amount;
		`geometry.p.y[it] = `geometry.n.y[it]*`amount;
		`geometry.p.z[it] = `geometry.n.z[it]*`amount;
	}
}
else
{
	for 0..`geometry.count-1
	{
		`geometry.p.x[it] = `geometry.n.x[it]*`amount;
		`geometry.p.y[it] = `geometry.n.y[it]*`amount;
		`geometry.p.z[it] = `geometry.n.z[it]*`amount;
	}
}

}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

make_geometry :: inline (count: s64, alignment: s64 = 4) -> Geometry
{
	result: Geometry;
	result.count = count;
	reserve(*result.p.x, count,, allocation=allocation(.Main, alignment));
	reserve(*result.p.y, count,, allocation=allocation(.Main, alignment));
	reserve(*result.p.z, count,, allocation=allocation(.Main, alignment));
	reserve(*result.n.x, count,, allocation=allocation(.Main, alignment));
	reserve(*result.n.y, count,, allocation=allocation(.Main, alignment));
	reserve(*result.n.z, count,, allocation=allocation(.Main, alignment));
	
	for 0..result.count-1
	{
		result.n.x[it] = 0.0;
		result.n.y[it] = 0.0;
		result.n.z[it] = 0.0;
	}
	
	return result;
}

reset_geometry :: inline (geometry: *Geometry)
{
	for 0..geometry.count-1
	{
		geometry.p.x[it] = 0.0;
		geometry.p.y[it] = 0.0;
		geometry.p.z[it] = 0.0;
	}
}

make_geometries :: inline (chunks: s64, count: s64, rest: s64, alignment: s64 = 4) -> Block(Geometry)
{
	result: Block(Geometry);
	reserve(*result, chunks);
	for *result
	{
		it.* = make_geometry(
			ifx rest != 0 && it_index == 0 then count + rest else count,
			alignment
		);
	}
	
	return result;
}

reset_geometries :: inline (geometries: Block(Geometry))
{
	for *geometries { reset_geometry(it); }
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
		
		work.geometry.chunk.p.x = .{count, geometry.p.x.data + offset};
		work.geometry.chunk.p.y = .{count, geometry.p.y.data + offset};
		work.geometry.chunk.p.z = .{count, geometry.p.z.data + offset};
		work.geometry.chunk.n.x = .{count, geometry.n.x.data + offset};
		work.geometry.chunk.n.y = .{count, geometry.n.y.data + offset};
		work.geometry.chunk.n.z = .{count, geometry.n.z.data + offset};
		
		work.geometry.amount = amount;
		
		add_work(work, sequentially=true);
	}
	
	completed.geometry_count = work_count;
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

check_geometry_work :: (geometry: Geometry, amount: float)
{
	for 0..geometry.count-1
	{
		expected_px := geometry.p.x[it];
		expected_py := geometry.p.y[it];
		expected_pz := geometry.p.z[it];
		computed_px := geometry.n.x[it]*amount;
		computed_py := geometry.n.y[it]*amount;
		computed_pz := geometry.n.z[it]*amount;
		
		assert(expected_px == computed_px);
		assert(expected_py == computed_py);
		assert(expected_pz == computed_pz);
	}
}

check_geometry_work :: (geometries: Block(Geometry), amount: float)
{
	for geometries
	{
		check_geometry_work(it, amount);
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
