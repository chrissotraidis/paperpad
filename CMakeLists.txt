cmake_minimum_required(VERSION 3.20)

project(PaperPad LANGUAGES C CXX)

if (APPLE)
    enable_language(OBJCXX)
endif()

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
    cmake_policy(SET CMP0135 NEW)
endif()

get_filename_component(PAPERPAD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
set(PM_RECOMP_OUT "${PAPERPAD_ROOT}/generated/aot/paper_mario_recomp_out")
set(PM_GENERATED_RSP "${PAPERPAD_ROOT}/generated/aot/rsp/n_aspMain.cpp")
set(PAPERPAD_RUNTIME "${PAPERPAD_ROOT}/ref/mstan-n64modernruntime")
set(PAPERPAD_RENDERER "${PAPERPAD_ROOT}/ref/mstan-rt64")

if (NOT EXISTS "${PM_RECOMP_OUT}/lookup.cpp")
    message(FATAL_ERROR
        "Missing generated Paper Mario recomp output at ${PM_RECOMP_OUT}. "
        "Generate it locally from your legally dumped Paper Mario (U) ROM: "
        "scripts/generate-game.sh")
endif()

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

# ---- Renderer: RT64 (mstan fork with Apple Metal support) ----------------
set(RT64_STATIC TRUE CACHE BOOL "Build RT64 as a static library" FORCE)
if (APPLE)
    set(RT64_SDL_WINDOW_VULKAN FALSE CACHE BOOL "Use SDL windows for RT64 Vulkan" FORCE)
endif()
add_compile_definitions(HLSL_CPU)
if (NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    # Vendored SDL2 2.32.10 static (built from build-ios-deps/sources) for the
    # macOS runner; avoids the Homebrew sdl2-compat shim (SDL3 underneath) that
    # hangs in SDL_ShowWindow's Cocoa restore path. RT64 consumes these vars.
    set(PAPERPAD_SDL2_STATIC_DIR "${PAPERPAD_ROOT}/build-macos-sdl2" CACHE PATH "Vendored SDL2 static build dir (macOS)")
    if (EXISTS "${PAPERPAD_SDL2_STATIC_DIR}/libSDL2.a")
        set(SDL2_INCLUDE_DIRS "${PAPERPAD_ROOT}/build-ios-deps/sources/include")
        set(SDL2_LIBRARIES "${PAPERPAD_SDL2_STATIC_DIR}/libSDL2.a")
    endif()
endif()
if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(RT64_BUILD_TOOLS OFF CACHE BOOL "RT64 host tools" FORCE)
    set(PAPERPAD_IOS_DIR "${PAPERPAD_ROOT}/apple/app" CACHE PATH "PaperPad iOS shell sources")
    set(DXC_PATH "${PAPERPAD_RENDERER}/src/contrib/dxc/bin/arm64/dxc-macos" CACHE FILEPATH "Host DXC")
    set(SPIRV_CROSS_MSL_PATH "${PAPERPAD_ROOT}/build/bin/spirv_cross_msl" CACHE FILEPATH "Host spirv_cross_msl")
    set(FILE_TO_C_PATH "${PAPERPAD_ROOT}/build-macos2/file_to_c" CACHE FILEPATH "Host file_to_c")
    find_package(SDL2 REQUIRED CONFIG)
endif()
add_subdirectory("${PAPERPAD_RENDERER}" "${CMAKE_BINARY_DIR}/rt64")

# ---- Runtime: N64ModernRuntime (mstan fork, static mobile profile) ---------
set(N64MODERN_NO_DYNAMIC_CODE ON CACHE BOOL "Compile out runtime code generation" FORCE)
set(WITH_ARES_BRIDGE OFF CACHE BOOL "" FORCE)
add_subdirectory("${PAPERPAD_RUNTIME}" "${CMAKE_BINARY_DIR}/runtime")

if (TARGET fmt)
    target_compile_definitions(fmt PUBLIC FMT_USE_CONSTEVAL=0)
endif()

# ---- Recompiled game functions ---------------------------------------------
add_library(RecompiledFuncs STATIC)
file(GLOB PM_FUNC_SOURCES "${PM_RECOMP_OUT}/*.c" "${PM_RECOMP_OUT}/*.cpp")
target_sources(RecompiledFuncs PRIVATE ${PM_FUNC_SOURCES})
target_compile_options(RecompiledFuncs PRIVATE
    -fno-strict-aliasing -Wno-unused-variable -Wno-implicit-function-declaration
)
target_include_directories(RecompiledFuncs PRIVATE
    "${PM_RECOMP_OUT}"
    "${PAPERPAD_ROOT}/src"
    "${PAPERPAD_RUNTIME}/ultramodern/include"
    "${PAPERPAD_RUNTIME}/librecomp/include"
    "${PAPERPAD_RUNTIME}/N64Recomp/include"
)

add_executable(PaperPad
    src/paperpad_main.cpp
    src/paperpad_paths.mm
    src/paper_rt64_context.cpp
    src/paper_stubs.cpp
    src/register_overlays.cpp
    src/builtin_texture_pack.cpp
    "${PM_RECOMP_OUT}/lookup.cpp"
    "${PM_GENERATED_RSP}"
)

if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_sources(PaperPad PRIVATE
        "${PAPERPAD_IOS_DIR}/ios_main.mm"
        "${PAPERPAD_IOS_DIR}/rom_setup.mm"
        "${PAPERPAD_IOS_DIR}/touch_tap_latch.h"
        "${PAPERPAD_IOS_DIR}/PrivacyInfo.xcprivacy"
        "${PAPERPAD_IOS_DIR}/ThirdPartyNotices.txt"
        "${PAPERPAD_IOS_DIR}/Assets.xcassets")
    set_source_files_properties(
        "${PAPERPAD_IOS_DIR}/PrivacyInfo.xcprivacy"
        "${PAPERPAD_IOS_DIR}/ThirdPartyNotices.txt"
        "${PAPERPAD_IOS_DIR}/Assets.xcassets"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_compile_definitions(PaperPad PRIVATE SDL_MAIN_HANDLED=1)
    set_target_properties(PaperPad PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${PAPERPAD_IOS_DIR}/Info.plist.in"
        MACOSX_BUNDLE_BUNDLE_NAME "PaperPad"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.chrissotraidis.paperpad"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
        OUTPUT_NAME "PaperPad"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${DEVELOPMENT_TEAM}"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.chrissotraidis.paperpad"
        XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
        # iPhone + iPad (native iPad layout, not the iPhone compatibility
        # window that UIDeviceFamily=[1] would force on iPadOS).
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
elseif (APPLE)
    set_target_properties(PaperPad PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "PaperPad"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.chrissotraidis.paperpad"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "0.1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1")
endif()

target_include_directories(PaperPad PRIVATE
    "${PAPERPAD_ROOT}/src"
    "${PM_RECOMP_OUT}"
    "${PAPERPAD_RUNTIME}/ultramodern/include"
    "${PAPERPAD_RUNTIME}/librecomp/include"
    "${PAPERPAD_RUNTIME}/N64Recomp/include"
    "${PAPERPAD_RENDERER}/src/contrib"
    "${PAPERPAD_RENDERER}/src/contrib/hlslpp/include"
    "${PAPERPAD_RENDERER}/src"
    "${PAPERPAD_RENDERER}/src/rhi"
    "${PAPERPAD_RENDERER}/src/render"
    "${CMAKE_BINARY_DIR}/rt64/src"
    "${SDL2_INCLUDE_DIRS}"
)

if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_include_directories(PaperPad PRIVATE
        "${PAPERPAD_IOS_DIR}"
        "${PAPERPAD_RUNTIME}/N64Recomp/include")
endif()

target_link_libraries(PaperPad PRIVATE
    RecompiledFuncs
    librecomp
    ultramodern
    rt64
)
if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_link_libraries(PaperPad PRIVATE SDL2::SDL2-static "-framework UIKit -framework Metal -framework QuartzCore -framework CoreGraphics -framework Foundation -framework UniformTypeIdentifiers")
else()
    # Use the vendored SDL2 2.32.10 static build (same source as the iOS
    # target) instead of the Homebrew sdl2-compat shim (SDL3 underneath),
    # which can hang in SDL_ShowWindow's Cocoa restore path.
    set(PAPERPAD_SDL2_STATIC_DIR "${PAPERPAD_ROOT}/build-macos-sdl2" CACHE PATH "Vendored SDL2 static build dir (macOS)")
    if (EXISTS "${PAPERPAD_SDL2_STATIC_DIR}/libSDL2.a")
        target_link_libraries(PaperPad PRIVATE "${PAPERPAD_SDL2_STATIC_DIR}/libSDL2.a"
            "-framework Cocoa -framework CoreVideo -framework IOKit -framework ForceFeedback -framework Carbon -framework CoreGraphics -framework AudioToolbox -framework CoreAudio -framework GameController -framework CoreHaptics")
    else()
        target_link_libraries(PaperPad PRIVATE SDL2::SDL2)
    endif()
endif()
