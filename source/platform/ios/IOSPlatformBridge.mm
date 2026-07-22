/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#include "IOSPlatformBridge.h"

#include <TargetConditionals.h>
#include <UIKit/UIKit.h>

#include <cstddef>
#include <string>

#if !TARGET_OS_IOS
#error "IOSPlatformBridge must only be built for iOS"
#endif

NSNotificationName const IOSPlatformBridgeDiagnosticsDidChangeNotification =
	@"IOSPlatformBridgeDiagnosticsDidChangeNotification";

namespace
{
IOSPlatformBridge::LifecycleState g_LifecycleState = IOSPlatformBridge::LifecycleState::Launching;
std::string g_LastLifecycleEvent = "not-reported";
std::size_t g_MemoryWarningCount = 0;

const char* ArchitectureName()
{
#if defined(__arm64__) || defined(__aarch64__)
	return "arm64";
#elif defined(__x86_64__)
	return "x86_64";
#else
	return "unknown";
#endif
}

const char* EnvironmentName()
{
#if TARGET_OS_SIMULATOR
	return "iPad Simulator";
#else
	return "iPadOS device";
#endif
}

const char* StateName(const IOSPlatformBridge::LifecycleState state)
{
	switch (state)
	{
	case IOSPlatformBridge::LifecycleState::Launching:
		return "launching";
	case IOSPlatformBridge::LifecycleState::Active:
		return "active";
	case IOSPlatformBridge::LifecycleState::Inactive:
		return "inactive";
	case IOSPlatformBridge::LifecycleState::Background:
		return "background";
	case IOSPlatformBridge::LifecycleState::Disconnected:
		return "disconnected";
	case IOSPlatformBridge::LifecycleState::Terminating:
		return "terminating";
	}
	return "unknown";
}

void AssertMainThread()
{
	NSCAssert(NSThread.isMainThread, @"iPadOS shell diagnostics must be updated on the main thread");
}

void NotifyDiagnosticsChanged()
{
	[NSNotificationCenter.defaultCenter
		postNotificationName:IOSPlatformBridgeDiagnosticsDidChangeNotification
		object:nil];
}
}

void IOSPlatformBridge::Log(const std::string_view message)
{
	const std::string ownedMessage{message};
	NSLog(@"[Pyrogenesis iPadOS] %s", ownedMessage.c_str());
}

void IOSPlatformBridge::Initialize(const std::string_view sourceRevision)
{
	AssertMainThread();
	g_LifecycleState = LifecycleState::Launching;
	g_LastLifecycleEvent = "application-did-finish-launching";
	g_MemoryWarningCount = 0;
	Log(std::string{"launch revision="} + std::string{sourceRevision} +
		" architecture=" + ArchitectureName() + " environment=" + EnvironmentName());
	NotifyDiagnosticsChanged();
}

void IOSPlatformBridge::SetLifecycleState(
	const LifecycleState state, const std::string_view event)
{
	AssertMainThread();
	g_LifecycleState = state;
	g_LastLifecycleEvent.assign(event.data(), event.size());
	Log(std::string{"lifecycle-event="} + g_LastLifecycleEvent +
		" state=" + StateName(g_LifecycleState));
	NotifyDiagnosticsChanged();
}

void IOSPlatformBridge::ReportMemoryWarning()
{
	AssertMainThread();
	++g_MemoryWarningCount;
	g_LastLifecycleEvent = "application-memory-warning";
	Log(std::string{"memory-warning count="} + std::to_string(g_MemoryWarningCount));
	NotifyDiagnosticsChanged();
}

void IOSPlatformBridge::ReportSafeArea(
	const double top, const double left, const double bottom, const double right)
{
	AssertMainThread();
	Log(std::string{"safe-area top="} + std::to_string(top) +
		" left=" + std::to_string(left) + " bottom=" + std::to_string(bottom) +
		" right=" + std::to_string(right));
}

void IOSPlatformBridge::ReportViewSize(
	const double width, const double height, const double nativeScale)
{
	AssertMainThread();
	Log(std::string{"view-size-points width="} + std::to_string(width) +
		" height=" + std::to_string(height) +
		" native-scale=" + std::to_string(nativeScale));
}

IOSPlatformBridge::DiagnosticsSnapshot IOSPlatformBridge::GetDiagnosticsSnapshot()
{
	AssertMainThread();
	return {
		ArchitectureName(),
		EnvironmentName(),
		StateName(g_LifecycleState),
		g_LastLifecycleEvent,
		g_MemoryWarningCount};
}
