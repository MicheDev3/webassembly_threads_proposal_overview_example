
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
			using chunk: *Geometry;
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

init_geometry :: (geometries: *Block(Geometry), chunks: s64, points: s64, rest: s64, alignment: s64)
{
	reserve(geometries, chunks);
	for *geometries
	{
		count := ifx rest != 0 && it_index == geometries.count - 1 then points + rest else points;
		reserve(*it.positions, count,, allocation=allocation(.Main, alignment));
		reserve(*it.normals,   count,, allocation=allocation(.Main, alignment));
	}
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

push_geometry_work :: (geometries: Block(Geometry), completed: *WorkCompleted, secondary_thread_count: s64)
{
	amount := 1.0; work_count: s64;
	while work_count < secondary_thread_count
	{
		work: WorkAvailable;
		work.type = .Geometry;
		work.geometry.chunk = *geometries[work_count];
		work.geometry.amount = amount;
		
		add_work(work, sequentially=true);
		
		amount += 1.0;
		
		work_count += 1;
	}
	
	if geometries.count > secondary_thread_count
	{
		work: WorkAvailable;
		work.type = .Geometry;
		work.geometry.chunk = *geometries[work_count];
		work.geometry.amount = amount;
		
		process_available_work(*work);
	}
	
	completed.geometry_count = secondary_thread_count;
}

check_geometry_work :: (geometries: Block(Geometry))
{
	for geometries
	{
		normals   := it.normals;
		positions := it.positions;
		amount := cast(float)(it_index+1);
		for positions
		{
			position := normals[it_index]*amount;
			assert(it == position);
		}
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
