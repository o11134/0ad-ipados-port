/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#import "IOSAppDelegate.h"

#import "IOSBuildConfig.h"
#import "IOSPlatformBridge.h"

@implementation IOSAppDelegate

- (BOOL)application:(UIApplication*)application
	didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions
{
	(void)application;
	(void)launchOptions;

	IOSPlatformBridge::Initialize(IPADOS_SOURCE_REVISION);
	IOSPlatformBridge::Log("M2_SHELL_LAUNCHED");
	return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication*)application
{
	(void)application;
	IOSPlatformBridge::ReportMemoryWarning();
}

- (void)applicationWillTerminate:(UIApplication*)application
{
	(void)application;
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Terminating, "application-will-terminate");
}

- (UIInterfaceOrientationMask)application:(UIApplication*)application
	supportedInterfaceOrientationsForWindow:(UIWindow*)window
{
	(void)application;
	(void)window;
	return UIInterfaceOrientationMaskLandscape;
}

@end
