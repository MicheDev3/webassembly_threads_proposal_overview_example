
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

Work :: struct
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
	// TODO: Properly init the geometry
	for *geometry.normals
	{
		it.* = .{1, 1, 1};
	}
}

thread_proc :: (data: *void)
{
	work := cast(*Work) data;
	
	if #complete work.type ==
	{
		case .Geometry;
		{
			geometry := work.geometry;
			
			for geometry.normals
			{
				position := it*geometry.amount;
				geometry.positions[it_index] += position;
			}
		}
	}
}

/////////////////////////////


/////////////////////////////
// Imports
/////////////////////////////

#import "Math";

/////////////////////////////
