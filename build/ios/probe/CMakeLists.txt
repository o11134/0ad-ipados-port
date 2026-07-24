cmake_minimum_required(VERSION 3.25)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
	message(FATAL_ERROR "Platform probe must be configured with -DCMAKE_SYSTEM_NAME=iOS")
endif()

if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
	message(FATAL_ERROR "Platform probe requires CMake's Xcode generator")
endif()

set(IPADOS_DEPLOYMENT_TARGET "17.0" CACHE STRING "Minimum supported iPadOS version")
set(IPADOS_UPSTREAM_SOURCE "" CACHE PATH "Path to the upstream 0 A.D. source workspace")
set(CMAKE_OSX_DEPLOYMENT_TARGET "${IPADOS_DEPLOYMENT_TARGET}" CACHE STRING "" FORCE)
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "" FORCE)
set(CMAKE_XCODE_GENERATE_SCHEME ON)

project(PyrogenesisPlatformProbe LANGUAGES C CXX OBJC OBJCXX)

if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
	message(FATAL_ERROR "Platform probe can only be generated on macOS")
endif()

if(IPADOS_UPSTREAM_SOURCE STREQUAL "" OR NOT EXISTS "${IPADOS_UPSTREAM_SOURCE}/source/lib/sysdep/os.h")
	message(FATAL_ERROR "IPADOS_UPSTREAM_SOURCE must point to a prepared upstream workspace containing source/lib/sysdep/os.h")
endif()

get_filename_component(PORT_REPOSITORY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

add_executable(PyrogenesisPlatformProbe MACOSX_BUNDLE
	"${PORT_REPOSITORY_ROOT}/source/platform/probe/PlatformProbe.mm")

target_include_directories(PyrogenesisPlatformProbe PRIVATE
	"${IPADOS_UPSTREAM_SOURCE}/source")

target_compile_features(PyrogenesisPlatformProbe PRIVATE cxx_std_17)
target_compile_options(PyrogenesisPlatformProbe PRIVATE -Wall -Wextra)

target_link_libraries(PyrogenesisPlatformProbe PRIVATE
	"-framework Foundation"
	"-framework UIKit")

set_target_properties(PyrogenesisPlatformProbe PROPERTIES
	CXX_EXTENSIONS NO
	CXX_STANDARD 17
	CXX_STANDARD_REQUIRED YES
	OBJCXX_EXTENSIONS NO
	OBJCXX_STANDARD 17
	OBJCXX_STANDARD_REQUIRED YES
	OUTPUT_NAME "PyrogenesisPlatformProbe"
	XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES "YES"
	XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
	XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
	XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IPADOS_DEPLOYMENT_TARGET}"
	XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.example.pyrogenesis.platform-probe"
	XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2"
	MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/ProbeInfo.plist.in")
