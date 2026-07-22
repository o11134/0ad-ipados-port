/* Copyright (C) 2026 Wildfire Games.
 * This file is part of 0 A.D.
 *
 * 0 A.D. is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */

#import "IOSViewController.h"

#import "IOSBuildConfig.h"
#import "IOSPlatformBridge.h"

namespace
{
NSString* StringFromUtf8(const std::string& value)
{
	NSString* string = [NSString stringWithUTF8String:value.c_str()];
	return string ? string : @"unavailable";
}

NSString* SceneActivationStateName(const UISceneActivationState state)
{
	switch (state)
	{
	case UISceneActivationStateUnattached:
		return @"unattached";
	case UISceneActivationStateForegroundActive:
		return @"foreground-active";
	case UISceneActivationStateForegroundInactive:
		return @"foreground-inactive";
	case UISceneActivationStateBackground:
		return @"background";
	}
	return @"unknown";
}

BOOL AutomaticSandboxProbeRequested()
{
	NSProcessInfo* processInfo = NSProcessInfo.processInfo;
	if ([processInfo.arguments containsObject:@"--m2-sandbox-probe"])
		return YES;

	return [processInfo.environment[@"M2_AUTOMATIC_SANDBOX_PROBE"] isEqualToString:@"1"];
}
}

@interface IOSViewController ()

@property(strong, nonatomic) UILabel* diagnosticsLabel;
@property(strong, nonatomic) UILabel* sandboxResultLabel;
@property(assign, nonatomic) CGSize lastReportedViewSize;
@property(assign, nonatomic) CGFloat lastReportedNativeScale;
@property(assign, nonatomic) BOOL hasReportedMetrics;
@property(assign, nonatomic) BOOL hasRunAutomaticSandboxProbe;

- (void)runSandboxProbeAutomatically:(BOOL)automatic;
- (void)finishSandboxProbeWithStep:(NSString*)step
	error:(NSError*)error
	automatic:(BOOL)automatic;

@end

@implementation IOSViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.075 blue:0.095 alpha:1.0];

	NSDictionary* bundleInfo = NSBundle.mainBundle.infoDictionary;
	NSString* productName = bundleInfo[@"CFBundleDisplayName"];
	if (productName.length == 0)
		productName = bundleInfo[@"CFBundleName"];
	if (productName.length == 0)
		productName = @"Pyrogenesis iPad Shell";

	UILabel* title = [[UILabel alloc] init];
	title.translatesAutoresizingMaskIntoConstraints = NO;
	title.text = productName;
	title.textColor = UIColor.whiteColor;
	title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
	title.adjustsFontForContentSizeCategory = YES;
	title.textAlignment = NSTextAlignmentCenter;
	title.numberOfLines = 0;
	title.accessibilityIdentifier = @"ipados-shell-title";

	UILabel* subtitle = [[UILabel alloc] init];
	subtitle.translatesAutoresizingMaskIntoConstraints = NO;
	subtitle.text = @"Standalone, unofficial M2 diagnostic shell — engine integration disabled";
	subtitle.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
	subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
	subtitle.adjustsFontForContentSizeCategory = YES;
	subtitle.textAlignment = NSTextAlignmentCenter;
	subtitle.numberOfLines = 0;

	self.diagnosticsLabel = [[UILabel alloc] init];
	self.diagnosticsLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.diagnosticsLabel.text = @"Awaiting the first view layout…";
	self.diagnosticsLabel.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
	self.diagnosticsLabel.font = [UIFont monospacedSystemFontOfSize:15.0 weight:UIFontWeightRegular];
	self.diagnosticsLabel.adjustsFontForContentSizeCategory = YES;
	self.diagnosticsLabel.textAlignment = NSTextAlignmentLeft;
	self.diagnosticsLabel.numberOfLines = 0;
	self.diagnosticsLabel.accessibilityIdentifier = @"ipados-shell-diagnostics";

	UIButton* sandboxButton = [UIButton buttonWithType:UIButtonTypeSystem];
	sandboxButton.translatesAutoresizingMaskIntoConstraints = NO;
	UIButtonConfiguration* buttonConfiguration = [UIButtonConfiguration filledButtonConfiguration];
	buttonConfiguration.title = @"Run Sandbox Read/Write Test";
	sandboxButton.configuration = buttonConfiguration;
	[sandboxButton addTarget:self
		action:@selector(runSandboxProbe:)
		forControlEvents:UIControlEventTouchUpInside];
	sandboxButton.accessibilityIdentifier = @"ipados-shell-sandbox-button";
	[sandboxButton.heightAnchor constraintGreaterThanOrEqualToConstant:44.0].active = YES;

	self.sandboxResultLabel = [[UILabel alloc] init];
	self.sandboxResultLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.sandboxResultLabel.text = @"Sandbox read/write: NOT RUN";
	self.sandboxResultLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
	self.sandboxResultLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	self.sandboxResultLabel.adjustsFontForContentSizeCategory = YES;
	self.sandboxResultLabel.textAlignment = NSTextAlignmentCenter;
	self.sandboxResultLabel.numberOfLines = 0;
	self.sandboxResultLabel.accessibilityIdentifier = @"ipados-shell-sandbox-result";

	UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
		title, subtitle, self.diagnosticsLabel, sandboxButton, self.sandboxResultLabel
	]];
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	stack.axis = UILayoutConstraintAxisVertical;
	stack.alignment = UIStackViewAlignmentFill;
	stack.spacing = 14.0;

	UIScrollView* scrollView = [[UIScrollView alloc] init];
	scrollView.translatesAutoresizingMaskIntoConstraints = NO;
	scrollView.alwaysBounceVertical = YES;
	[self.view addSubview:scrollView];
	[scrollView addSubview:stack];

	UILayoutGuide* safeArea = self.view.safeAreaLayoutGuide;
	[NSLayoutConstraint activateConstraints:@[
		[scrollView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
		[scrollView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor],
		[scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
		[scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor constant:24.0],
		[stack.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor constant:-24.0],
		[stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:20.0],
		[stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-20.0],
		[stack.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor constant:-48.0]
	]];

	[NSNotificationCenter.defaultCenter addObserver:self
		selector:@selector(platformDiagnosticsDidChange:)
		name:IOSPlatformBridgeDiagnosticsDidChangeNotification
		object:nil];
}

- (void)dealloc
{
	[NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self refreshDiagnostics];

	if (!self.hasRunAutomaticSandboxProbe && AutomaticSandboxProbeRequested())
	{
		self.hasRunAutomaticSandboxProbe = YES;
		[self runSandboxProbeAutomatically:YES];
	}
}

- (void)viewDidLayoutSubviews
{
	[super viewDidLayoutSubviews];

	UIScreen* screen = self.view.window.windowScene.screen;
	const CGFloat nativeScale = screen ? screen.nativeScale : 0.0;
	const CGSize viewSize = self.view.bounds.size;
	if (!self.hasReportedMetrics ||
		!CGSizeEqualToSize(viewSize, self.lastReportedViewSize) ||
		ABS(nativeScale - self.lastReportedNativeScale) > 0.001)
	{
		self.hasReportedMetrics = YES;
		self.lastReportedViewSize = viewSize;
		self.lastReportedNativeScale = nativeScale;
		IOSPlatformBridge::ReportViewSize(viewSize.width, viewSize.height, nativeScale);
	}

	[self refreshDiagnostics];
}

- (void)viewSafeAreaInsetsDidChange
{
	[super viewSafeAreaInsetsDidChange];
	const UIEdgeInsets insets = self.view.safeAreaInsets;
	IOSPlatformBridge::ReportSafeArea(insets.top, insets.left, insets.bottom, insets.right);
	[self refreshDiagnostics];
}

- (void)platformDiagnosticsDidChange:(NSNotification*)notification
{
	(void)notification;
	[self refreshDiagnostics];
}

- (void)refreshDiagnostics
{
	if (!self.isViewLoaded)
		return;

	NSDictionary* bundleInfo = NSBundle.mainBundle.infoDictionary;
	NSString* productName = bundleInfo[@"CFBundleDisplayName"];
	if (productName.length == 0)
		productName = bundleInfo[@"CFBundleName"];
	if (productName.length == 0)
		productName = @"Pyrogenesis iPad Shell";
	NSString* version = bundleInfo[@"CFBundleShortVersionString"];
	if (version.length == 0)
		version = @"unknown";
	NSString* buildNumber = bundleInfo[@"CFBundleVersion"];
	if (buildNumber.length == 0)
		buildNumber = @"unknown";
	NSString* revision = [NSString stringWithUTF8String:IPADOS_SOURCE_REVISION];
	if (!revision)
		revision = @"unknown";
	NSString* configuration = [NSString stringWithUTF8String:IPADOS_BUILD_CONFIGURATION];
	if (!configuration)
		configuration = @"unknown";
	UIDevice* device = UIDevice.currentDevice;
	UIScreen* screen = self.view.window.windowScene.screen;
	const CGSize screenSize = screen ? screen.bounds.size : CGSizeZero;
	const CGSize viewSize = self.view.bounds.size;
	const CGFloat nativeScale = screen ? screen.nativeScale : 0.0;
	const UIEdgeInsets insets = self.view.safeAreaInsets;
	UIWindowScene* windowScene = self.view.window.windowScene;
	NSString* sceneState = windowScene ? SceneActivationStateName(windowScene.activationState) : @"unattached";
	const IOSPlatformBridge::DiagnosticsSnapshot snapshot = IOSPlatformBridge::GetDiagnosticsSnapshot();

	NSString* diagnostics = [NSString stringWithFormat:
		@"App: %@ %@ (%@)\n"
		 "Build type: %@\n"
		 "Source revision: %@\n"
		 "CPU / target: %@ / %@\n"
		 "OS: %@ %@\n"
		 "Screen (points): %.0f × %.0f\n"
		 "View (points): %.0f × %.0f\n"
		 "Native scale: %.2f\n"
		 "Safe insets T/L/B/R: %.1f / %.1f / %.1f / %.1f\n"
		 "Scene state: %@\n"
		 "Lifecycle state: %@\n"
		 "Last lifecycle event: %@\n"
		 "Memory warnings: %zu",
		 productName, version, buildNumber,
		 configuration, revision,
		 StringFromUtf8(snapshot.architecture), StringFromUtf8(snapshot.environment),
		 device.systemName, device.systemVersion,
		 screenSize.width, screenSize.height,
		 viewSize.width, viewSize.height,
		 nativeScale,
		 insets.top, insets.left, insets.bottom, insets.right,
		 sceneState,
		 StringFromUtf8(snapshot.lifecycleState),
		 StringFromUtf8(snapshot.lifecycleEvent),
		 snapshot.memoryWarningCount];

	if (![self.diagnosticsLabel.text isEqualToString:diagnostics])
		self.diagnosticsLabel.text = diagnostics;
}

- (void)runSandboxProbe:(UIButton*)sender
{
	(void)sender;
	[self runSandboxProbeAutomatically:NO];
}

- (void)runSandboxProbeAutomatically:(BOOL)automatic
{
	self.sandboxResultLabel.text = @"Sandbox read/write: RUNNING…";
	self.sandboxResultLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];

	NSFileManager* fileManager = NSFileManager.defaultManager;
	NSError* error = nil;
	NSURL* applicationSupport = [fileManager URLForDirectory:NSApplicationSupportDirectory
		inDomain:NSUserDomainMask
		appropriateForURL:nil
		create:YES
		error:&error];
	if (!applicationSupport)
	{
		[self finishSandboxProbeWithStep:@"locate-directory" error:error automatic:automatic];
		return;
	}

	NSURL* probeURL = [applicationSupport URLByAppendingPathComponent:@"m2-sandbox-probe.txt"
		isDirectory:NO];
	NSData* expected = [@"Pyrogenesis iPad Shell sandbox probe v1\n"
		dataUsingEncoding:NSUTF8StringEncoding];
	if (![expected writeToURL:probeURL options:NSDataWritingAtomic error:&error])
	{
		[self finishSandboxProbeWithStep:@"write" error:error automatic:automatic];
		return;
	}

	NSData* actual = [NSData dataWithContentsOfURL:probeURL options:0 error:&error];
	if (!actual)
	{
		[self finishSandboxProbeWithStep:@"read" error:error automatic:automatic];
		return;
	}

	if (![expected isEqualToData:actual])
	{
		[self finishSandboxProbeWithStep:@"read-back-mismatch" error:nil automatic:automatic];
		return;
	}

	self.sandboxResultLabel.text = [NSString stringWithFormat:
		@"Sandbox read/write: PASS (%lu bytes, Application Support)",
		(unsigned long)actual.length];
	self.sandboxResultLabel.textColor = [UIColor colorWithRed:0.42 green:0.86 blue:0.56 alpha:1.0];
	IOSPlatformBridge::Log("sandbox-probe result=PASS location=application-support");
	if (automatic)
		IOSPlatformBridge::Log("M2_SANDBOX_PROBE_PASS");
	UIAccessibilityPostNotification(
		UIAccessibilityAnnouncementNotification, self.sandboxResultLabel.text);
}

- (void)finishSandboxProbeWithStep:(NSString*)step
	error:(NSError*)error
	automatic:(BOOL)automatic
{
	NSString* domain = error.domain;
	if (!domain)
		domain = @"none";
	const NSInteger code = error ? error.code : -1;
	self.sandboxResultLabel.text = [NSString stringWithFormat:
		@"Sandbox read/write: FAIL (%@; %@/%ld)", step, domain, (long)code];
	self.sandboxResultLabel.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.42 alpha:1.0];
	NSString* logMessage = [NSString stringWithFormat:
		@"sandbox-probe result=FAIL step=%@ error-domain=%@ error-code=%ld",
		step, domain, (long)code];
	const char* utf8LogMessage = logMessage.UTF8String;
	IOSPlatformBridge::Log(utf8LogMessage ? utf8LogMessage : "sandbox-probe result=FAIL");
	if (automatic)
	{
		NSString* automaticLogMessage = [NSString stringWithFormat:
			@"M2_SANDBOX_PROBE_FAIL step=%@ error-domain=%@ error-code=%ld",
			step, domain, (long)code];
		const char* utf8AutomaticLogMessage = automaticLogMessage.UTF8String;
		IOSPlatformBridge::Log(utf8AutomaticLogMessage ? utf8AutomaticLogMessage :
			"M2_SANDBOX_PROBE_FAIL");
	}
	UIAccessibilityPostNotification(
		UIAccessibilityAnnouncementNotification, self.sandboxResultLabel.text);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
	return UIInterfaceOrientationLandscapeRight;
}

- (BOOL)shouldAutorotate
{
	return YES;
}

@end
