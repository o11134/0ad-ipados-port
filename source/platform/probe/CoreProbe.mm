/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#import <UIKit/UIKit.h>

#include "lib/sysdep/os.h"
#include "lib/timer.h"

#include <cstdio>

static void RunCoreTimerProbe()
{
	printf("PYROGENESIS_CORE_PROBE\n");
	printf("M3_CORE_BOOTSTRAP_STARTED\n");
	NSLog(@"[Pyrogenesis CoreProbe] M3_CORE_BOOTSTRAP_STARTED");

	// Call real upstream Pyrogenesis timer subsystem functions
	timer_Init();

	const double t0 = timer_Time();
	const double resolution = timer_Resolution();

	// Safe milliseconds sleep using Apple Foundation
	[NSThread sleepForTimeInterval:0.010];

	const double t1 = timer_Time();

	printf("M3_TIMER_TIME_0=%.6f\n", t0);
	printf("M3_TIMER_TIME_1=%.6f\n", t1);
	printf("M3_TIMER_RESOLUTION=%.9f\n", resolution);

	NSLog(@"[Pyrogenesis CoreProbe] M3_TIMER_TIME_0=%.6f M3_TIMER_TIME_1=%.6f M3_TIMER_RESOLUTION=%.9f",
		t0, t1, resolution);

	const bool resolutionValid = (resolution > 0.0);
	const bool t0Valid = (t0 >= 0.0);
	const bool monotonicityValid = (t1 >= t0);

	if (resolutionValid && t0Valid && monotonicityValid)
	{
		printf("M3_TIMER_INIT_PASS\n");
		printf("M3_CORE_BOOTSTRAP_PASS\n");
		NSLog(@"[Pyrogenesis CoreProbe] M3_TIMER_INIT_PASS");
		NSLog(@"[Pyrogenesis CoreProbe] M3_CORE_BOOTSTRAP_PASS");
	}
	else
	{
		printf("M3_CORE_BOOTSTRAP_FAIL\n");
		NSLog(@"[Pyrogenesis CoreProbe] M3_CORE_BOOTSTRAP_FAIL");
	}

	fflush(stdout);
}

@interface CoreProbeAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation CoreProbeAppDelegate

- (BOOL)application:(UIApplication*)application
	didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions
{
	(void)application;
	(void)launchOptions;
	RunCoreTimerProbe();
	return YES;
}

@end

int main(int argc, char* argv[])
{
	@autoreleasepool
	{
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(CoreProbeAppDelegate.class));
	}
}
