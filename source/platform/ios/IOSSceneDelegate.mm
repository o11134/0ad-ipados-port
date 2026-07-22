/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#import "IOSSceneDelegate.h"

#import "IOSPlatformBridge.h"
#import "IOSViewController.h"

@implementation IOSSceneDelegate

- (void)scene:(UIScene*)scene
	willConnectToSession:(UISceneSession*)session
	options:(UISceneConnectionOptions*)connectionOptions
{
	(void)session;
	(void)connectionOptions;
	if (![scene isKindOfClass:UIWindowScene.class])
		return;

	UIWindowScene* windowScene = (UIWindowScene*)scene;
	self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
	self.window.rootViewController = [[IOSViewController alloc] init];
	[self.window makeKeyAndVisible];
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Inactive, "scene-will-connect");
}

- (void)sceneDidBecomeActive:(UIScene*)scene
{
	(void)scene;
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Active, "scene-did-become-active");
}

- (void)sceneWillResignActive:(UIScene*)scene
{
	(void)scene;
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Inactive, "scene-will-resign-active");
}

- (void)sceneDidEnterBackground:(UIScene*)scene
{
	(void)scene;
	// Engine integration will synchronously pause simulation and audio here.
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Background, "scene-did-enter-background");
}

- (void)sceneWillEnterForeground:(UIScene*)scene
{
	(void)scene;
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Inactive, "scene-will-enter-foreground");
}

- (void)sceneDidDisconnect:(UIScene*)scene
{
	(void)scene;
	IOSPlatformBridge::SetLifecycleState(
		IOSPlatformBridge::LifecycleState::Disconnected, "scene-did-disconnect");
}

@end
