
/////////////////////////////
// Enums
/////////////////////////////

WorkType :: enum
{
	Geometry;
	Summation;
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
			using _: Geometry;
			amount: float;
		}
		summation: *Summation;
	}
}

WorkCompleted :: struct
{
	geometry_\count: s64;
	summation_count: s64;
}

// TODO: Either make sure each work is padded to a cache line (ideal) or
// pad the Vector3 definition here
Geometry :: struct
{
	positions: Block(Vector3);
	normals:   Block(Vector3);
}

Summation :: struct
{
	count:  u64;
	result: u64;
}

Statistics :: struct
{
	min: u64;
	avg: u64;
	max: u64;
	
	min = 0xffff_ffff_ffff_ffff;
}

/////////////////////////////


/////////////////////////////
// Operators
/////////////////////////////

operator == :: inline (lhs: $T/WorkCompleted, rhs: T) -> bool
{
    result := (
        lhs.geometry_\count == rhs.geometry_\count
        &&
        lhs.summation_count == rhs.summation_count
    );
    
    return result;
}

operator >= :: inline (lhs: $T/WorkCompleted, rhs: T) -> bool
{
    result := (
        lhs.geometry_\count >= rhs.geometry_\count
        &&
        lhs.summation_count >= rhs.summation_count
    );
    
    return result;
}

operator + :: inline (lhs: $T/WorkCompleted, rhs: T) -> T
{
    result: T = ---;
    result.geometry_\count = lhs.geometry_\count + rhs.geometry_\count;
    result.summation_count = lhs.summation_count + rhs.summation_count;
    
    return result;
}

operator += :: inline (lhs: *$T/WorkCompleted, rhs: T)
{
    lhs.geometry_\count += rhs.geometry_\count;
    lhs.summation_count += rhs.summation_count;
}

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

init_geometry :: (geometry: *Geometry, count: s64)
{
	reserve(*geometry.positions, count);
	reserve(*geometry.normals,   count);
}

init_summations :: (summations: *Block(Summation), count: s64)
{
	reserve(summations, count);
}

reset_geometry :: (geometry: *Geometry)
{
	for *geometry.positions { it.* = .{0, 0, 0}; }
	for *geometry.normals   { it.* = .{1, 1, 1}; }
}

reset_summations :: (summations: *Block(Summation))
{
	for *summations { it.* = .{}; }
}

push_geometry_work :: (completed: *WorkCompleted, thread_count: s64, point_count: s64, stats: *Statistics)
{
	iterations := thread_count;
	points_per_thread := point_count / thread_count;

	amount := 1.0; work_count: s64;
	
	while work_count < iterations
	{
		start := rdtsc();
		work: WorkAvailable;
		work.type = .Geometry;
		work.geometry.positions = .{points_per_thread, GEOMETRY.positions.data + work_count*points_per_thread};
		work.geometry.normals   = .{points_per_thread, GEOMETRY.normals\ .data + work_count*points_per_thread};
		work.geometry.amount = amount;
		
		add_work(work, sequentially=true);
		
		elapsed := rdtsc() - start;
		if elapsed < stats.min stats.min = elapsed;
		if elapsed > stats.max stats.max = elapsed;
		stats.avg += elapsed;
		
		amount += 1.0;
		
		work_count += 1;
	}
	
	stats.avg /= cast(u64)iterations;
	
	// NOTE: working out the rest
	if work_count*points_per_thread < POINTS_COUNT
	{
		offset := work_count*points_per_thread;
		
		work: WorkAvailable;
		work.type = .Geometry;
		work.geometry.positions = .{POINTS_COUNT - offset, GEOMETRY.positions.data + offset};
		work.geometry.normals   = .{POINTS_COUNT - offset, GEOMETRY.normals\ .data + offset};
		work.geometry.amount = amount;
		
		process_available_work(*work);
	}
	
	completed.geometry_count = iterations;
}

check_geometry_work :: (geometry: *Geometry, thread_count: s64, point_count: s64)
{
	amount := 0.0;
	points_per_thread := POINTS_COUNT / thread_count;
	for geometry.positions
	{
		if it_index % points_per_thread == 0
		{
			amount += 1;
		}
		
		normal   := geometry.normals[it_index];
		position := normal*amount;
		assert(it == position);
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
			
			for geometry.normals
			{
				position := it*geometry.amount;
				geometry.positions[it_index] += position;
			}
		}
		case .Summation;
		{
			summation := a.summation;
			
			result: u64;
			for 1..summation.count
			{
				result += it;
			}
			
			summation.result = result;
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
		case .Summation;
		{
			c.summation_count += 1;
		}
	}
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Math";

/////////////////////////////
