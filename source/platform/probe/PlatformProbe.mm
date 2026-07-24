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
#include "lib/sysdep/arch.h"

#include <cstdio>

static void PrintProbeResults()
{
	printf("PYROGENESIS_PLATFORM_PROBE\n");

#ifdef OS_IOS
	printf("OS_IOS=1\n");
#else
	printf("OS_IOS=0\n");
#endif

#ifdef OS_MACOSX
	printf("OS_MACOSX=1\n");
#else
	printf("OS_MACOSX=0\n");
#endif

#ifdef OS_UNIX
	printf("OS_UNIX=1\n");
#else
	printf("OS_UNIX=0\n");
#endif

#ifdef OS_WIN
	printf("OS_WIN=1\n");
#else
	printf("OS_WIN=0\n");
#endif

#ifdef OS_LINUX
	printf("OS_LINUX=1\n");
#else
	printf("OS_LINUX=0\n");
#endif

#if defined(__arm64__) || defined(__aarch64__)
	printf("ARCH_ARM64=1\n");
#else
	printf("ARCH_ARM64=0\n");
#endif

#if defined(__x86_64__)
	printf("ARCH_X86_64=1\n");
#else
	printf("ARCH_X86_64=0\n");
#endif

#ifdef TARGET_OS_SIMULATOR
	printf("TARGET_OS_SIMULATOR=%d\n", TARGET_OS_SIMULATOR);
#else
	printf("TARGET_OS_SIMULATOR=unavailable\n");
#endif

#ifdef TARGET_OS_IPHONE
	printf("TARGET_OS_IPHONE=%d\n", TARGET_OS_IPHONE);
#else
	printf("TARGET_OS_IPHONE=unavailable\n");
#endif

	printf("sizeof_void_ptr=%zu\n", sizeof(void*));
	printf("PROBE_COMPLETE\n");
	fflush(stdout);

	NSLog(@"[Pyrogenesis PlatformProbe] OS_IOS=%d OS_MACOSX=%d OS_UNIX=%d ARCH_ARM64=%d",
#ifdef OS_IOS
		1,
#else
		0,
#endif
#ifdef OS_MACOSX
		1,
#else
		0,
#endif
#ifdef OS_UNIX
		1,
#else
		0,
#endif
#if defined(__arm64__) || defined(__aarch64__)
		1
#else
		0
#endif
	);
}

@interface ProbeAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation ProbeAppDelegate

- (BOOL)application:(UIApplication*)application
	didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions
{
	(void)application;
	(void)launchOptions;
	PrintProbeResults();
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
		dispatch_get_main_queue(), ^{
			[UIApplication.sharedApplication performSelector:@selector(suspend)];
		});
	return YES;
}

@end

int main(int argc, char* argv[])
{
	@autoreleasepool
	{
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(ProbeAppDelegate.class));
	}
}
