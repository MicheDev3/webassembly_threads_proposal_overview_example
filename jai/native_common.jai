
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

LANES :: 4;
SIMD  :: true;

// NOTE: By default RUN_CHECK_GEOMETRY_WORK is disable as it will decrease performance
// quite a lot. I think because it is polluting the cache
RUN_CHECK_GEOMETRY_WORK :: false;
PRINT_ITERATION_TIMES   :: false;

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

PlatformInitThreads :: #type 
(
	thread_count: u32,
	main_memory_size: s64,
	temp_memory_size: s64
) -> bool, Block(PlatformThread);
PlatformFiniThreads :: #type (threads: Block(PlatformThread));

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

		UPDATE_GEOMETRY();
		
		datapoints[it-1] = rdtsc() - start;
		
		FREE(.Temp);
	}
	
	result := perform_statistics(datapoints, false);
	print("Process % iterations (POINT_COUNT=%, THREADS=%, SIMD=%, LANES=%, POINTS_IN_SINGLE_CHUNK=%, RUN_CHECK_GEOMETRY_WORK=%)\n", ITERATIONS, POINT_COUNT, 0, SIMD, LANES, false, RUN_CHECK_GEOMETRY_WORK ,, allocation=allocation(.Temp));
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

	success, threads := platform_init_threads(secondary_thread_count, thread_memory_size, temp_memory_size);
	defer
	{
		shutdown();

		platform_fini_threads(threads);
	}
	
	if !success
	{
		print("Failed to create threads\n",, allocation=allocation(.Temp));
		return .{};
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
	
	result := perform_statistics(datapoints, PRINT_ITERATION_TIMES);
	print("Process % iterations (POINT_COUNT=%, THREADS=%, SIMD=%, LANES=%, POINTS_IN_SINGLE_CHUNK=%, RUN_CHECK_GEOMETRY_WORK=%)\n", ITERATIONS, POINT_COUNT, secondary_thread_count, SIMD, LANES, POINTS_IN_SINGLE_CHUNK, RUN_CHECK_GEOMETRY_WORK ,, allocation=allocation(.Temp));
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

perform_statistics :: (datapoints: []u64, $print_iteration_time: bool) -> Statistics
{
	result: Statistics;
	reset_stats(*result);
	for datapoints
	{
#if print_iteration_time
{
		print("ITERATION(%) = %\n", FormatInt.{value=it_index+1, minimum_digits=4}, it,, allocation=allocation(.Temp));
}
		compute_stats(*result, it);
	}
	
	finalize_stats(*result, datapoints);
	
	return result;
}

/////////////////////////////