/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#import <UIKit/UIKit.h>

#include "lib/debug.h"
#include "lib/timer.h"
#include "ps/ThreadUtil.h"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <pthread.h>
#include <thread>

namespace
{

void LogMarker(const char* marker)
{
	printf("%s\n", marker);
	NSLog(@"[Pyrogenesis ThreadProbe] %s", marker);
}

void LogFailure(const char* reason)
{
	printf("M3_C2_BOOTSTRAP_FAIL reason=%s\n", reason);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_C2_BOOTSTRAP_FAIL reason=%s", reason);
	fflush(stdout);
}

bool RunThreadProbe()
{
	LogMarker("M3_C2_CORE_REGRESSION_STARTED");

	timer_Init();
	const double t0 = timer_Time();
	const double resolution = timer_Resolution();
	std::this_thread::sleep_for(std::chrono::milliseconds(10));
	const double t1 = timer_Time();

	printf("M3_C2_CORE_TIME_0=%.6f\n", t0);
	printf("M3_C2_CORE_TIME_1=%.6f\n", t1);
	printf("M3_C2_CORE_RESOLUTION=%.9f\n", resolution);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_C2_CORE_TIME_0=%.6f", t0);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_C2_CORE_TIME_1=%.6f", t1);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_C2_CORE_RESOLUTION=%.9f", resolution);

	if (resolution <= 0.0 || t0 < 0.0 || t1 < t0)
	{
		LogFailure("core-regression");
		return false;
	}
	LogMarker("M3_C2_CORE_REGRESSION_PASS");

	LogMarker("M3_THREAD_BOOTSTRAP_STARTED");
	Threading::SetMainThread();

	const bool mainIsMain = Threading::IsMainThread();
	printf("M3_MAIN_IS_MAIN=%d\n", mainIsMain ? 1 : 0);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_MAIN_IS_MAIN=%d", mainIsMain ? 1 : 0);
	if (!mainIsMain)
	{
		LogFailure("main-thread-identity");
		return false;
	}
	LogMarker("M3_MAIN_THREAD_PASS");

	bool workerIsMain = true;
	std::thread worker([&workerIsMain]() {
		workerIsMain = Threading::IsMainThread();
	});
	worker.join();

	printf("M3_WORKER_IS_MAIN=%d\n", workerIsMain ? 1 : 0);
	printf("M3_WORKER_JOINED=1\n");
	NSLog(@"[Pyrogenesis ThreadProbe] M3_WORKER_IS_MAIN=%d", workerIsMain ? 1 : 0);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_WORKER_JOINED=1");
	if (workerIsMain)
	{
		LogFailure("worker-thread-identity");
		return false;
	}
	LogMarker("M3_WORKER_THREAD_PASS");

	const bool mainIsMainAfterJoin = Threading::IsMainThread();
	printf("M3_MAIN_POST_JOIN_IS_MAIN=%d\n", mainIsMainAfterJoin ? 1 : 0);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_MAIN_POST_JOIN_IS_MAIN=%d", mainIsMainAfterJoin ? 1 : 0);
	if (!mainIsMainAfterJoin)
	{
		LogFailure("post-join-main-thread-identity");
		return false;
	}
	LogMarker("M3_MAIN_THREAD_POST_JOIN_PASS");

	debug_SetThreadName("main");
	char threadName[64] = {};
	const int getNameResult = pthread_getname_np(pthread_self(), threadName, sizeof(threadName));
	printf("M3_PTHREAD_GETNAME_RESULT=%d\n", getNameResult);
	printf("M3_DEBUG_THREAD_NAME_VALUE=%s\n", getNameResult == 0 ? threadName : "<unavailable>");
	NSLog(@"[Pyrogenesis ThreadProbe] M3_PTHREAD_GETNAME_RESULT=%d", getNameResult);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_DEBUG_THREAD_NAME_VALUE=%s",
		getNameResult == 0 ? threadName : "<unavailable>");
	if (getNameResult != 0 || std::strcmp(threadName, "main") != 0)
	{
		LogFailure("debug-thread-name");
		return false;
	}
	LogMarker("M3_DEBUG_THREAD_NAME_PASS");

	const bool filterBefore = debug_filter_allows("FILES|M3-C2");
	printf("M3_DEBUG_FILTER_BEFORE=%d\n", filterBefore ? 1 : 0);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_DEBUG_FILTER_BEFORE=%d", filterBefore ? 1 : 0);

	debug_filter_add("FILES");

	const bool filterAfter = debug_filter_allows("FILES|M3-C2");
	printf("M3_DEBUG_FILTER_AFTER=%d\n", filterAfter ? 1 : 0);
	NSLog(@"[Pyrogenesis ThreadProbe] M3_DEBUG_FILTER_AFTER=%d", filterAfter ? 1 : 0);
	if (filterBefore || !filterAfter)
	{
		LogFailure("debug-filter-transition");
		return false;
	}
	LogMarker("M3_DEBUG_FILTER_PASS");

	LogMarker("M3_C2_BOOTSTRAP_PASS");
	fflush(stdout);
	return true;
}

} // anonymous namespace

@interface ThreadProbeAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation ThreadProbeAppDelegate

- (BOOL)application:(UIApplication*)application
	didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions
{
	(void)application;
	(void)launchOptions;
	(void)RunThreadProbe();
	return YES;
}

@end

int main(int argc, char* argv[])
{
	@autoreleasepool
	{
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(ThreadProbeAppDelegate.class));
	}
}
