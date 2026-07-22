/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#ifndef INCLUDED_IOSPLATFORMBRIDGE
#define INCLUDED_IOSPLATFORMBRIDGE

#include <cstddef>
#include <string>
#include <string_view>

#ifdef __OBJC__
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSNotificationName const IOSPlatformBridgeDiagnosticsDidChangeNotification;
#endif

namespace IOSPlatformBridge
{
enum class LifecycleState
{
	Launching,
	Active,
	Inactive,
	Background,
	Disconnected,
	Terminating
};

struct DiagnosticsSnapshot
{
	std::string architecture;
	std::string environment;
	std::string lifecycleState;
	std::string lifecycleEvent;
	std::size_t memoryWarningCount;
};

void Initialize(std::string_view sourceRevision);
void SetLifecycleState(LifecycleState state, std::string_view event);
void ReportMemoryWarning();
void ReportSafeArea(double top, double left, double bottom, double right);
void ReportViewSize(double width, double height, double nativeScale);
DiagnosticsSnapshot GetDiagnosticsSnapshot();
void Log(std::string_view message);
}

#endif // INCLUDED_IOSPLATFORMBRIDGE
