cmake_minimum_required(VERSION 3.25)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
	message(FATAL_ERROR "This scaffold must be configured with -DCMAKE_SYSTEM_NAME=iOS")
endif()

if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
	message(FATAL_ERROR "The iPadOS shell requires CMake's Xcode generator")
endif()

set(IPADOS_DEPLOYMENT_TARGET "17.0" CACHE STRING "Minimum supported iPadOS version")
set(IPADOS_BUNDLE_IDENTIFIER "org.example.pyrogenesis.ipadshell" CACHE STRING "Development bundle identifier")
set(IPADOS_PRODUCT_NAME "Pyrogenesis iPad Shell" CACHE STRING "Local shell product name")
set(IPADOS_DEVELOPMENT_TEAM "" CACHE STRING "Local Apple Development Team ID; never commit a personal value")
set(IPADOS_SOURCE_REVISION "unknown" CACHE STRING "Source revision printed by the application shell")
set(CMAKE_OSX_DEPLOYMENT_TARGET "${IPADOS_DEPLOYMENT_TARGET}" CACHE STRING "" FORCE)
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "" FORCE)
set(CMAKE_XCODE_GENERATE_SCHEME ON)

project(PyrogenesisIPadShell LANGUAGES C CXX OBJC OBJCXX)

if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
	message(FATAL_ERROR "The iPadOS Xcode project can only be generated on macOS; see docs/ipados/MAC_HANDOFF.md")
endif()

if(IPADOS_SOURCE_REVISION STREQUAL "unknown")
	find_package(Git QUIET)
	if(Git_FOUND)
		execute_process(
			COMMAND "${GIT_EXECUTABLE}" rev-parse --short=12 HEAD
			WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/../.."
			RESULT_VARIABLE IPADOS_GIT_RESULT
			OUTPUT_VARIABLE IPADOS_GIT_REVISION
			OUTPUT_STRIP_TRAILING_WHITESPACE)
		if(IPADOS_GIT_RESULT EQUAL 0 AND NOT IPADOS_GIT_REVISION STREQUAL "")
			set(IPADOS_SOURCE_REVISION "${IPADOS_GIT_REVISION}")
		endif()
	endif()
endif()

configure_file(
	"${CMAKE_CURRENT_LIST_DIR}/IOSBuildConfig.h.in"
	"${CMAKE_CURRENT_BINARY_DIR}/generated/IOSBuildConfig.h"
	@ONLY)

add_executable(PyrogenesisIPadShell MACOSX_BUNDLE
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSAppDelegate.h"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSAppDelegate.mm"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSPlatformBridge.h"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSPlatformBridge.mm"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSSceneDelegate.h"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSSceneDelegate.mm"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSViewController.h"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/IOSViewController.mm"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios/main.mm")

target_compile_features(PyrogenesisIPadShell PRIVATE cxx_std_17)
target_include_directories(PyrogenesisIPadShell PRIVATE
	"${CMAKE_CURRENT_BINARY_DIR}/generated"
	"${CMAKE_CURRENT_LIST_DIR}/../../source/platform/ios")
target_compile_options(PyrogenesisIPadShell PRIVATE -Wall -Wextra -Wpedantic)
target_compile_definitions(PyrogenesisIPadShell PRIVATE
	"IPADOS_BUILD_CONFIGURATION=\"$<CONFIG>\"")
target_link_libraries(PyrogenesisIPadShell PRIVATE
	"-framework CoreGraphics"
	"-framework Foundation"
	"-framework QuartzCore"
	"-framework UIKit")

set_target_properties(PyrogenesisIPadShell PROPERTIES
	CXX_EXTENSIONS NO
	CXX_STANDARD 17
	CXX_STANDARD_REQUIRED YES
	MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/Info.plist.in"
	OBJCXX_EXTENSIONS NO
	OBJCXX_STANDARD 17
	OBJCXX_STANDARD_REQUIRED YES
	OUTPUT_NAME "${IPADOS_PRODUCT_NAME}"
	XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES "YES"
	XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
	XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
	XCODE_ATTRIBUTE_CURRENT_PROJECT_VERSION "1"
	XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
	XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IPADOS_DEPLOYMENT_TARGET}"
	XCODE_ATTRIBUTE_MARKETING_VERSION "0.0.1"
	XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${IPADOS_BUNDLE_IDENTIFIER}"
	XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST "NO"
	XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2")

if(NOT IPADOS_DEVELOPMENT_TEAM STREQUAL "")
	set_target_properties(PyrogenesisIPadShell PROPERTIES
		XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${IPADOS_DEVELOPMENT_TEAM}")
endif()

message(STATUS "iPadOS shell revision: ${IPADOS_SOURCE_REVISION}")
message(STATUS "iPadOS deployment target: ${IPADOS_DEPLOYMENT_TARGET}")
message(STATUS "iPadOS bundle identifier: ${IPADOS_BUNDLE_IDENTIFIER}")
message(STATUS "iPadOS product name: ${IPADOS_PRODUCT_NAME}")
if(IPADOS_DEVELOPMENT_TEAM STREQUAL "")
	message(STATUS "Development Team: not stored; select it locally in Xcode")
endif()
