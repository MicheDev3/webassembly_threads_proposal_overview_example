
/////////////////////////////
// Loads
/////////////////////////////

#load "common.jai";

/////////////////////////////


/////////////////////////////
// Constants
/////////////////////////////

ITERATIONS :: 1000;
LOGGING    :: false;

POINT_COUNT :: 10_000_004;
POINTS_PER_THREAD :: 100000;

SPLIT_POINTS_BY_THREAD :: true;
// NOTE: if POINTS_IN_SINGLE_CHUNK, we can use easily 10M points. I think because this
// will maximize cache utilization? 
POINTS_IN_SINGLE_CHUNK :: true;

SIMD :: true;
// TODO: AVX runs terribly in single_threaded_test, while it is fine in multi_threaded_test.
// Try to understand exactly why and how to solve it.
// I found this thread with useful info:
// https://community.intel.com/t5/Intel-ISA-Extensions/Need-help-Why-my-avx-code-is-slower-than-SSE-code/m-p/1034874 
AVX  :: false;

// NOTE: By default RUN_CHECK_GEOMETRY_WORK is disable as it will decrease performance
// quite a lot. I think because it is polluting the cache?
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

single_threaded_test :: (entropy: *Random_State, page_size: s64) -> Statistics
{
	main_memory_size   := align_forward(MAIN_MEMORY_SIZE  , page_size);
	temp_memory_size   := align_forward(TEMP_MEMORY_SIZE  , page_size);
	thread_memory_size := align_forward(THREAD_MEMORY_SIZE, page_size);
	
	allocator: ArenaAllocator;
	init_arena(*allocator, main_memory_size, temp_memory_size);
	context.allocator.data = *allocator;

	datapoints: [ITERATIONS]u64;
	geometry := make_geometry(POINT_COUNT, CACHE_LINE_SIZE);
	for 1..ITERATIONS
	{
#if RUN_CHECK_GEOMETRY_WORK
{
		reset_geometry(*geometry);
}
		amount := floor(random_get_within_range(entropy, 1.0, 100.0));

		start := rdtsc();
		UPDATE_GEOMETRY();
		datapoints[it-1] = rdtsc() - start;
		
#if RUN_CHECK_GEOMETRY_WORK
{
		check_geometry_work(geometry, amount);
}
		
		FREE(.Temp);
	}
	
	result := perform_statistics(datapoints, false);
	print("Single threaded time elapsed to complete work: \n",, allocation=allocation(.Temp));
	print("        - min = %\n", result.min      ,, allocation=allocation(.Temp));
	print("        - avg = %\n", result.avg      ,, allocation=allocation(.Temp));
	print("        - max = %\n", result.max      ,, allocation=allocation(.Temp));
	print("        - std = %\n", result.std_dev  ,, allocation=allocation(.Temp));
	print("\n",, allocation=allocation(.Temp));
	
	return result;
}

multi_threaded_test :: (entropy: *Random_State, worker_count: u32, page_size: s64) -> Statistics
{	
	main_memory_size   := align_forward(MAIN_MEMORY_SIZE  , page_size);
	temp_memory_size   := align_forward(TEMP_MEMORY_SIZE  , page_size);
	thread_memory_size := align_forward(THREAD_MEMORY_SIZE, page_size);
	
	allocator: ArenaAllocator;
	init_arena(*allocator, main_memory_size, temp_memory_size);
	context.allocator.data = *allocator;
	
	init_thread_group(enable_logging=true, cast(u64)(current_time_monotonic().high));

	success, threads := platform_init_threads(worker_count, thread_memory_size, temp_memory_size);
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

#if SPLIT_POINTS_BY_THREAD
{	
	work_count: s64 = worker_count;
	
	rest: s64;
	points := POINT_COUNT / work_count;
	if work_count*points < POINT_COUNT
	{
		rest = POINT_COUNT - work_count*points; 
	}
}
else
{	
	rest: s64;
	points := POINTS_PER_THREAD;
	work_count := POINT_COUNT / points;
	if work_count*points < POINT_COUNT
	{
		rest = POINT_COUNT - work_count*points; 
	}
}
	
#if !POINTS_IN_SINGLE_CHUNK
{

	geometries := make_geometries(work_count, points, rest, CACHE_LINE_SIZE);
}
else
{
	geometry := make_geometry(POINT_COUNT);
}
	
	datapoints: [ITERATIONS]u64;
	for 1..ITERATIONS
	{

#if RUN_CHECK_GEOMETRY_WORK
{

#if !POINTS_IN_SINGLE_CHUNK
{
		reset_geometries(geometries);
}
else
{
		reset_geometry(*geometry);
}

}
		amount := floor(random_get_within_range(entropy, 1.0, 100.0));
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
	print("Multi threaded time elapsed to complete work: \n",, allocation=allocation(.Temp));
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

print_test_configurations :: (thread_count: u32)
{
	print("Test configurations:\n");
	print("    - simd:                    %\n", SIMD                    ,, allocation=allocation(.Temp));
	print("    - avx:                     %\n", AVX                     ,, allocation=allocation(.Temp));
	print("    - thread count:            %\n", thread_count            ,, allocation=allocation(.Temp));
	print("    - iterations:              %\n", ITERATIONS              ,, allocation=allocation(.Temp));
	print("    - point count:             %\n", POINT_COUNT             ,, allocation=allocation(.Temp));
	print("    - points per thread:       %\n", POINTS_PER_THREAD       ,, allocation=allocation(.Temp));
	print("    - points in single array:  %\n", POINTS_IN_SINGLE_CHUNK  ,, allocation=allocation(.Temp));
	print("    - run check geometry work: %\n", RUN_CHECK_GEOMETRY_WORK ,, allocation=allocation(.Temp));
	print("\n"                                                          ,, allocation=allocation(.Temp));
}

/////////////////////////////