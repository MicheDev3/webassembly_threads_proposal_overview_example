
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

#if SOA
{

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

}
else
{

Geometry :: struct
{
	p: Block(Vector3);
	n: Block(Vector3);
	
	count: s64;
}

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

#if SOA
{

UPDATE_GEOMETRY :: () #expand
{

#if SIMD
{
	// TODO: Fix AVX
	#assert(AVX == false);
	
	// TODO: Why is DYNAMIC_MEMORY slower? 
	DYNAMIC_MEMORY :: 0;
#if DYNAMIC_MEMORY
{
	amount: *f32 = ALLOCATE(LANES,, temp);
	for 0..LANES-1 { amount[it] = `amount; }
	
	tx: *f32 = ALLOCATE(LANES,, temp);
	ty: *f32 = ALLOCATE(LANES,, temp);
	tz: *f32 = ALLOCATE(LANES,, temp);
}
else
{
	amount := make_lane(`amount);

	tx: Lane = ---; ty: Lane = ---; tz: Lane = ---;
}

	iterations := (`geometry.count / LANES);
	
	px := `geometry.p.x.data; nx := `geometry.n.x.data;
	py := `geometry.p.y.data; ny := `geometry.n.y.data;
	pz := `geometry.p.z.data; nz := `geometry.n.z.data;

	for 0..iterations-1
	{
#if DYNAMIC_MEMORY
{
		mulps(tx, nx, amount);
		mulps(ty, ny, amount);
		mulps(tz, nz, amount);

		addps(px, tx);
		addps(py, ty);
		addps(pz, tz);
}
else
{
		mulps(tx.data, nx, amount.data);
		mulps(ty.data, ny, amount.data);
		mulps(tz.data, nz, amount.data);

		addps(px, tx.data);
		addps(py, ty.data);
		addps(pz, tz.data);
}
		
		px += LANES; nx += LANES;
		py += LANES; ny += LANES;
		pz += LANES; nz += LANES;
	}

	for iterations*LANES..`geometry.count-1
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

}
else
{

UPDATE_GEOMETRY :: () #expand
{

#if SIMD
{
	// TODO: Implement AVX
	#assert(AVX == false);
	
	a := make_lane(`amount);
	
	iterations := (`geometry.count / LANES);
	
	p := `geometry.p.data; n := `geometry.n.data;

	for 0..iterations-1
	{	
		px: Lane = .[p[0].x, p[1].x, p[2].x, p[3].x];
		py: Lane = .[p[0].y, p[1].y, p[2].y, p[3].y];
		pz: Lane = .[p[0].z, p[1].z, p[2].z, p[3].z];
		
		nx: Lane = .[n[0].x, n[1].x, n[2].x, n[3].x];
		ny: Lane = .[n[0].y, n[1].y, n[2].y, n[3].y];
		nz: Lane = .[n[0].z, n[1].z, n[2].z, n[3].z];

		mulps(nx.data, a.data);
		mulps(ny.data, a.data);
		mulps(nz.data, a.data);

		addps(px.data, nx.data);
		addps(py.data, ny.data);
		addps(pz.data, nz.data);
		
		p[0] = .{px[0], py[0], pz[0]};
		p[1] = .{px[1], py[1], pz[1]};
		p[2] = .{px[2], py[2], pz[2]};
		p[3] = .{px[3], py[3], pz[3]};
		
		p += LANES; n += LANES;
	}
	
	for iterations*LANES..`geometry.count-1
	{
		`geometry.p[it] = `geometry.n[it]*`amount;
	}
}
else
{
	for *`geometry.p
	{
		it.* += `geometry.n[it_index]*`amount;
	}
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
#if SOA
{
	result.count = count;
	reserve(*result.p.x, count,, allocation=allocation(alignment));
	reserve(*result.p.y, count,, allocation=allocation(alignment));
	reserve(*result.p.z, count,, allocation=allocation(alignment));
	reserve(*result.n.x, count,, allocation=allocation(alignment, ~.ClearToZero));
	reserve(*result.n.y, count,, allocation=allocation(alignment, ~.ClearToZero));
	reserve(*result.n.z, count,, allocation=allocation(alignment, ~.ClearToZero));
	
	for 0..result.count-1
	{
		result.n.x[it] = 1.0;
		result.n.y[it] = 1.0;
		result.n.z[it] = 1.0;
	}
}
else
{
	result.count = count;
	reserve(*result.p, result.count,, allocation=allocation(alignment));
	reserve(*result.n, result.count,, allocation=allocation(alignment, ~.ClearToZero));
	
	for *result.n { it.* = .{1, 1, 1}; }
}
	
	return result;
}

reset_geometry :: inline (geometry: *Geometry)
{

#if SOA
{
	for 0..geometry.count-1
	{
		geometry.p.x[it] = 0.0;
		geometry.p.y[it] = 0.0;
		geometry.p.z[it] = 0.0;
	}
}
else
{
	for *geometry.p { it.* = .{0, 0, 0}; }
}

}

make_geometries :: inline (chunks: s64, count: s64, rest: s64, alignment: s64 = 4) -> Block(Geometry)
{
	result: Block(Geometry);
	reserve(*result, chunks,, allocation=allocation(flags=~.ClearToZero));
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

#if SOA
{
		work.geometry.chunk.p.x = .{count, geometry.p.x.data + offset};
		work.geometry.chunk.p.y = .{count, geometry.p.y.data + offset};
		work.geometry.chunk.p.z = .{count, geometry.p.z.data + offset};
		work.geometry.chunk.n.x = .{count, geometry.n.x.data + offset};
		work.geometry.chunk.n.y = .{count, geometry.n.y.data + offset};
		work.geometry.chunk.n.z = .{count, geometry.n.z.data + offset};
		work.geometry.count = count;
}
else
{
		work.geometry.chunk.p = .{count, geometry.p.data + offset};
		work.geometry.chunk.n = .{count, geometry.n.data + offset};
}		
		work.geometry.amount = amount;
		
		add_work(work);
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
		
		add_work(work);
	}
	
	completed.geometry_count = geometries.count;
}

check_geometry_work :: (geometry: Geometry, amount: float)
{

#if SOA
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
else
{
	for expected: geometry.p
	{
		computed := geometry.n[it_index]*amount;
		assert(expected == computed);
	}
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
