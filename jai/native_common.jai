#assert(OS == .WINDOWS || OS == .LINUX);

/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";
#load "simd.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

ITERATIONS :: 1000;
LOGGING    :: false;

// POINT_COUNT :: 10_000_004;
POINT_COUNT :: 1_000_004;

POINTS_IN_SINGLE_CHUNK :: false;

SIMD :: true;

// NOTE: By default RUN_CHECK_GEOMETRY_WORK is disable as it will decrease performance
// quite a lot. I think because it is polluting the cache
RUN_CHECK_GEOMETRY_WORK :: false;

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

single_threaded_test :: (page_size: s64) -> Statistics
{
	main_memory_size   := align_forward(MAIN_MEMORY_SIZE  , page_size);
	temp_memory_size   := align_forward(TEMP_MEMORY_SIZE  , page_size);
	thread_memory_size := align_forward(THREAD_MEMORY_SIZE, page_size);
	
	allocator: ArenaAllocator;
	init_arena(*allocator, main_memory_size, temp_memory_size);
	context.allocator.data = *allocator;

	geometry: Geometry;
	init_geometry(*geometry, POINT_COUNT);
	reset_geometry(*geometry);
	
	datapoints: [ITERATIONS]u64;
	for 1..ITERATIONS
	{
		start := rdtsc();

		count  := 0;
		amount := 1.0;

		positions := geometry.positions;
		normals   := geometry.normals;
#if SIMD
{
		amount_4x := toM128(amount);
		iterations := (normals.count / LANES);
		while count < iterations
		{
			defer count += 1;
			
			p := positions.data + (count*LANES);
			n := normals.data   + (count*LANES);
			
			position_4x := toVector34x(p[0], p[1], p[2], p[3]);
			normal\ _4x := toVector34x(n[0], n[1], n[2], n[3]);
			
			computed := position_4x + (normal_4x*amount_4x);
			
			p[0] = .{computed.x[0], computed.y[0], computed.z[0]};
			p[1] = .{computed.x[1], computed.y[1], computed.z[1]};
			p[2] = .{computed.x[2], computed.y[2], computed.z[2]};
			p[3] = .{computed.x[3], computed.y[3], computed.z[3]};
		}
}		

		for count*LANES..positions.count-1 
		{
			positions[it] += normals[it]*amount;
		}
		
		datapoints[it-1] = rdtsc() - start;
		
		FREE(.Temp);
	}
	
	result := perform_statistics(datapoints);
	print("Process % iterations (POINT_COUNT=%, THREADS=%, SIMD=%, POINTS_IN_SINGLE_CHUNK=%, RUN_CHECK_GEOMETRY_WORK=%)\n", ITERATIONS, POINT_COUNT, 0, SIMD, false, RUN_CHECK_GEOMETRY_WORK ,, allocation=allocation(.Temp));
	print("    time elapsed to complete work: \n",, allocation=allocation(.Temp));
	print("        - min = %\n", result.min      ,, allocation=allocation(.Temp));
	print("        - avg = %\n", result.avg      ,, allocation=allocation(.Temp));
	print("        - max = %\n", result.max      ,, allocation=allocation(.Temp));
	print("        - std = %\n", result.std_dev  ,, allocation=allocation(.Temp));
	print("\n",, allocation=allocation(.Temp));
	
	return result;
}

multi_threaded_test :: (all_thread_count: u32, page_size: s64) -> Statistics
{	
	if all_thread_count > MAX_THREAD_COUNT
	{
		all_thread_count = cast(u32)MAX_THREAD_COUNT;
	}

	// NOTE: excluding the processor running the main thread
	secondary_thread_count := all_thread_count - 1;
	
	main_memory_size   := align_forward(MAIN_MEMORY_SIZE  , page_size);
	temp_memory_size   := align_forward(TEMP_MEMORY_SIZE  , page_size);
	thread_memory_size := align_forward(THREAD_MEMORY_SIZE, page_size);
	
	allocator: ArenaAllocator;
	init_arena(*allocator, main_memory_size, temp_memory_size);
	context.allocator.data = *allocator;
	
	seed := current_time_monotonic();
	init_thread_group(enable_logging=true, cast(u64)seed.high);

#if OS ==
{
	case .WINDOWS;
		threads: Block(Win64Thread);
		reserve(*threads, secondary_thread_count);
		for 0..secondary_thread_count-1
		{
			thread := New(Win64Thread);
			thread.index = it;
			init_arena(*thread.allocator, thread_memory_size, temp_memory_size);
			init_thread(thread.index, *thread.allocator);
			
			ignored: s32;
			handle := _beginthreadex(null, 0, cast(*void)win64_thread_proc, thread, REALTIME_PRIORITY_CLASS, *ignored);
			assert(handle != null);
			
			thread.handle = cast(*void)handle;
			threads[it] = thread;
		}
	case .LINUX;
		threads: Block(LinuxThread);
		reserve(*threads, secondary_thread_count);
		for 0..secondary_thread_count-1
		{
			thread := New(LinuxThread);
			thread.index = cast(u32)it;
			init_arena(*thread.allocator, thread_memory_size, temp_memory_size);
			init_thread(thread.index, *thread.allocator);
			
			success := pthread_create(*thread.handle, null, linux_thread_proc, thread);
			assert(success ==  0);
			
			threads[it] = thread;
		}
	case;
		assert(false, "Unknown or unsupported os");
}
	// work_count: s64 = secondary_thread_count;
	
	// rest: s64;
	// points := POINT_COUNT / work_count;
	// if work_count*points < POINT_COUNT
	// {
	// 	rest = POINT_COUNT - work_count*points; 
	// }
	
	rest: s64;
	points := 10000;
	work_count := POINT_COUNT / points;
	if work_count*points < POINT_COUNT
	{
		rest = POINT_COUNT - work_count*points; 
	}
	
#if !POINTS_IN_SINGLE_CHUNK
{

	geometries: Block(Geometry);
	init_geometry(*geometries, work_count, points, rest, CACHE_LINE_SIZE);
}
else
{
	geometry: Geometry;
	init_geometry(*geometry, POINT_COUNT);
}

	entropy: Random_State;
	random_seed(*entropy, cast(u64)seed.high);
	
	datapoints: [ITERATIONS]u64;
	for 1..ITERATIONS
	{	
		amount := random_get_within_range(*entropy, 1.0, 100.0);
#if !POINTS_IN_SINGLE_CHUNK
{
		datapoints[it-1] = compute_work(geometries, amount);
}
else
{
		datapoints[it-1] = compute_work(*geometry, work_count, points, rest, amount);
}
		
		FREE(.Temp);
	}
	// TODO: Think more about how to time performance
	// print_thread_group_stats(,, allocation=allocation(.Temp));
	
	shutdown();
	
#if OS ==
{
	case .WINDOWS;
		for threads
		{
			CloseHandle(it.handle);
		}
	case .LINUX;
		for threads
		{
			pthread_join(it.handle, null);
		}
	case;
		assert(false, "Unknown or unsupported os");
}
	
	result := perform_statistics(datapoints);
	print("Process % iterations (POINT_COUNT=%, THREADS=%, SIMD=%, POINTS_IN_SINGLE_CHUNK=%, RUN_CHECK_GEOMETRY_WORK=%)\n", ITERATIONS, POINT_COUNT, secondary_thread_count, SIMD, POINTS_IN_SINGLE_CHUNK, RUN_CHECK_GEOMETRY_WORK ,, allocation=allocation(.Temp));
	print("    time elapsed to complete work: \n",, allocation=allocation(.Temp));
	print("        - min = %\n", result.min      ,, allocation=allocation(.Temp));
	print("        - avg = %\n", result.avg      ,, allocation=allocation(.Temp));
	print("        - max = %\n", result.max      ,, allocation=allocation(.Temp));
	print("        - std = %\n", result.std_dev  ,, allocation=allocation(.Temp));
	print("\n",, allocation=allocation(.Temp));
	
	return result;
}

compute_work :: inline (geometries: Block(Geometry), amount: float) -> u64
{
	current, target: WorkCompleted;
	push_geometry_work(geometries, *target, amount);

	result: u64;		
	start := rdtsc();
	while true
	{
GET_COMPLETE_WORK(#code
{
		current += completed;
});
		if current >= target
		{
			result = rdtsc() - start;
			
			assert(current == target);

			break;
		}
	}

#if RUN_CHECK_GEOMETRY_WORK
{
	check_geometry_work(geometries, amount);
}	
	return result;
}

compute_work :: inline (geometry: *Geometry, thread_count: s64, points: s64, rest: s64, amount: float) -> u64
{
	current, target: WorkCompleted;
	push_geometry_work(geometry, *target, thread_count, points, rest, amount);
	
	result: u64;
	start := rdtsc();
	while true
	{
GET_COMPLETE_WORK(#code
{
		current += completed;
});
		if current >= target
		{
			result = rdtsc() - start;
		
			assert(current == target);

			break;
		}
	}

#if RUN_CHECK_GEOMETRY_WORK
{
	check_geometry_work(geometry, amount);
}	
	return result;
}

perform_statistics :: (datapoints: []u64) -> Statistics
{
	result: Statistics;
	reset_stats(*result);
	for datapoints
	{
		// print("ITERATION(%) = %\n", FormatInt.{value=it_index+1, minimum_digits=4}, it,, allocation=allocation(.Temp));
		compute_stats(*result, it);
	}
	
	finalize_stats(*result, datapoints);
	
	return result;
}

/////////////////////////////