cmake_minimum_required(VERSION 3.25)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
	message(FATAL_ERROR "Pyrogenesis core probe must be configured with -DCMAKE_SYSTEM_NAME=iOS")
endif()

if(NOT CMAKE_GENERATOR STREQUAL "Xcode")
	message(FATAL_ERROR "Pyrogenesis core probe requires CMake's Xcode generator")
endif()

set(IPADOS_DEPLOYMENT_TARGET "17.0" CACHE STRING "Minimum supported iPadOS version")
set(IPADOS_UPSTREAM_SOURCE "" CACHE PATH "Path to the upstream 0 A.D. source workspace")
set(CMAKE_OSX_DEPLOYMENT_TARGET "${IPADOS_DEPLOYMENT_TARGET}" CACHE STRING "" FORCE)
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "" FORCE)
set(CMAKE_XCODE_GENERATE_SCHEME ON)

project(PyrogenesisCoreProbe LANGUAGES C CXX OBJC OBJCXX)

if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
	message(FATAL_ERROR "Pyrogenesis core probe can only be generated on macOS")
endif()

if(IPADOS_UPSTREAM_SOURCE STREQUAL "" OR NOT EXISTS "${IPADOS_UPSTREAM_SOURCE}/source/lib/sysdep/os.h")
	message(FATAL_ERROR "IPADOS_UPSTREAM_SOURCE must point to a prepared upstream workspace containing source/lib/sysdep/os.h")
endif()

get_filename_component(PORT_REPOSITORY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

# Static library containing real upstream Pyrogenesis timer/module_init core sources
add_library(PyrogenesisCoreIOS STATIC
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/timer.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/module_init.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/debug.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/status.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/utf8.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/path.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/os_path.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/app_hooks.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/secure_crt.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/sysdep/os/unix/unix.cpp"
	"${IPADOS_UPSTREAM_SOURCE}/source/lib/sysdep/os/unix/udbg.cpp")

target_include_directories(PyrogenesisCoreIOS PUBLIC
	"${IPADOS_UPSTREAM_SOURCE}/source")

target_compile_features(PyrogenesisCoreIOS PRIVATE cxx_std_17)
target_compile_options(PyrogenesisCoreIOS PRIVATE -Wall -Wextra)
target_compile_definitions(PyrogenesisCoreIOS PRIVATE CONFIG_ENABLE_PCH=0)

set_target_properties(PyrogenesisCoreIOS PROPERTIES
	CXX_EXTENSIONS NO
	CXX_STANDARD 17
	CXX_STANDARD_REQUIRED YES)

# Executable probe app target
add_executable(PyrogenesisCoreProbe MACOSX_BUNDLE
	"${PORT_REPOSITORY_ROOT}/source/platform/probe/CoreProbe.mm")

target_include_directories(PyrogenesisCoreProbe PRIVATE
	"${IPADOS_UPSTREAM_SOURCE}/source")

target_compile_features(PyrogenesisCoreProbe PRIVATE cxx_std_17)
target_compile_options(PyrogenesisCoreProbe PRIVATE -Wall -Wextra)

target_link_libraries(PyrogenesisCoreProbe PRIVATE
	PyrogenesisCoreIOS
	"-framework Foundation"
	"-framework UIKit")

set_target_properties(PyrogenesisCoreProbe PROPERTIES
	CXX_EXTENSIONS NO
	CXX_STANDARD 17
	CXX_STANDARD_REQUIRED YES
	OBJCXX_EXTENSIONS NO
	OBJCXX_STANDARD 17
	OBJCXX_STANDARD_REQUIRED YES
	OUTPUT_NAME "PyrogenesisCoreProbe"
	XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES "YES"
	XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
	XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
	XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "${IPADOS_DEPLOYMENT_TARGET}"
	XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.example.pyrogenesis.core-probe"
	XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2"
	MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/CoreProbeInfo.plist.in")
