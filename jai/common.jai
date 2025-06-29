
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
			using _: Geometry;
			amount: float;
		}
	}
}

WorkCompleted :: struct
{
	geometry_count: s64;
}

// TODO: Either make sure each work is padded to a cache line (ideal) or
// pad the Vector3 definition here
Geometry :: struct
{
	positions: Block(Vector3);
	normals:   Block(Vector3);
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

reset_geometry :: (geometry: *Geometry)
{
	for *geometry.positions { it.* = .{0, 0, 0}; }
	for *geometry.normals   { it.* = .{1, 1, 1}; }
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
			c.geometry_count += 1;
		}
	}
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Math";

/////////////////////////////
