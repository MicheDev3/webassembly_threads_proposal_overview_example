
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

POINT_COUNT :: 1_000_004;
POINTS_PER_THREAD :: 10_000;

SPLIT_POINTS_BY_THREAD :: false;
POINTS_IN_SINGLE_CHUNK :: false;

SOA :: true;

SIMD :: true;
// TODO: AVX runs terribly. Try to understand exactly why and how to solve it.
// I found this thread with useful info:
// https://community.intel.com/t5/Intel-ISA-Extensions/Need-help-Why-my-avx-code-is-slower-than-SSE-code/m-p/1034874 
AVX  :: false;

// NOTE: By default RUN_CHECK_GEOMETRY_WORK is disable as it will decrease performance
// quite a lot. I think because it is polluting the cache?
RUN_CHECK_GEOMETRY_WORK :: false;
PRINT_CSV_DATAPOINTS    :: false;

/////////////////////////////


/////////////////////////////
// Struct
/////////////////////////////

/////////////////////////////


/////////////////////////////
// Types
/////////////////////////////

PlatformInitThreads :: #type (thread_count: u32) -> bool, Block(PlatformThread);
PlatformFiniThreads :: #type (threads: Block(PlatformThread));

/////////////////////////////


/////////////////////////////
// Functions
/////////////////////////////

single_threaded_test :: (entropy: *Random_State) -> Statistics
{
	result: Statistics;
	reset_stats(*result);
	reserve(*result.datapoints, ITERATIONS);
	
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
		elapsed := rdtsc() - start;
		datapoint := insert(*result.datapoints);
		datapoint.* = elapsed;
		
#if RUN_CHECK_GEOMETRY_WORK
{
		check_geometry_work(geometry, amount);
}
		
		reset_temporary_storage();
	}
	
	perform_statistics(*result);
	print("Single threaded time elapsed to complete work: \n",, temp);
	print("        - min = %\n", result.min      ,, temp);
	print("        - avg = %\n", result.avg      ,, temp);
	print("        - max = %\n", result.max      ,, temp);
	print("        - std = %\n", result.std_dev  ,, temp);
	print("\n",, temp);
	
	return result;
}

multi_threaded_test :: (entropy: *Random_State, worker_count: u32) -> Statistics
{
	result: Statistics;
	reset_stats(*result);
	reserve(*result.datapoints, ITERATIONS);
	
	init_thread_group(enable_logging=true);
	success, threads := platform_init_threads(worker_count);
	defer
	{
		shutdown();

		platform_fini_threads(threads);
	}
	
	if !success
	{
		print("Failed to create threads\n",, temp);
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
		datapoint := insert(*result.datapoints);
		datapoint.* = compute_work(geometries, amount);
}
else
{
		datapoint := insert(*result.datapoints);
		datapoint.* = compute_work(*geometry, work_count, points, rest, amount);
}
		
		reset_temporary_storage();
	}
	
	perform_statistics(*result);
	print("Multi threaded time elapsed to complete work: \n",, temp);
	print("        - min = %\n", result.min      ,, temp);
	print("        - avg = %\n", result.avg      ,, temp);
	print("        - max = %\n", result.max      ,, temp);
	print("        - std = %\n", result.std_dev  ,, temp);
	print("\n",, temp);
	
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

print_test_configurations :: (now: string, thread_count: u32)
{
	print("Test configurations(%):\n", now                              ,, temp);
	print("    - soa:                     %\n", SOA                     ,, temp);
	print("    - simd:                    %\n", SIMD                    ,, temp);
	print("    - avx:                     %\n", AVX                     ,, temp);
	print("    - thread count:            %\n", thread_count            ,, temp);
	print("    - iterations:              %\n", ITERATIONS              ,, temp);
	print("    - point count:             %\n", POINT_COUNT             ,, temp);
	print("    - points per thread:       %\n", POINTS_PER_THREAD       ,, temp);
	print("    - points in single array:  %\n", POINTS_IN_SINGLE_CHUNK  ,, temp);
	print("    - run check geometry work: %\n", RUN_CHECK_GEOMETRY_WORK ,, temp);
	print("    - print csv datapoints:    %\n", PRINT_CSV_DATAPOINTS    ,, temp);
	print("\n"                                                          ,, temp);
}

/////////////////////////////