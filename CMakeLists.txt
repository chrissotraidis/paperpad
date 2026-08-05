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
set(PAPERPAD_RECUT_LIB "${PAPERPAD_ROOT}/ref/paper-mario-recut/lib")
set(PM_RECOMP_OUT "${PAPERPAD_ROOT}/generated/aot/paper_mario_recomp_out")
set(PM_GENERATED_RSP "${PAPERPAD_ROOT}/generated/aot/rsp/n_aspMain.cpp")
set(PM_ROM_PATH "${PAPERPAD_ROOT}/generated/rom/baserom.z64")

if (NOT EXISTS "${PM_RECOMP_OUT}/lookup.cpp")
    message(FATAL_ERROR
        "Missing generated Paper Mario recomp output at ${PM_RECOMP_OUT}. "
        "Generate it locally from your legally dumped Paper Mario (U) ROM: "
        "scripts/generate-game.sh")
endif()

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

set(RT64_STATIC TRUE CACHE BOOL "Build RT64 as a static library" FORCE)
if (WIN32)
    set(RT64_SDL_WINDOW_VULKAN OFF CACHE BOOL "Use SDL windows for RT64 Vulkan" FORCE)
    add_compile_definitions(HLSL_CPU)
elseif (NOT APPLE)
    # RT64 adds RT64_SDL_WINDOW_VULKAN itself only on Linux; on Apple the
    # Metal RHI + struct RenderWindow path is selected and the SDL_VULKAN
    # define must not leak into C++ (it would break the window typedef).
    set(RT64_SDL_WINDOW_VULKAN TRUE CACHE BOOL "Use SDL windows for RT64 Vulkan" FORCE)
    add_compile_definitions(HLSL_CPU)
else()
    set(RT64_SDL_WINDOW_VULKAN FALSE CACHE BOOL "Use SDL windows for RT64 Vulkan" FORCE)
    add_compile_definitions(HLSL_CPU)
endif()

add_subdirectory("${PAPERPAD_RECUT_LIB}/rt64" "${CMAKE_BINARY_DIR}/rt64")
add_subdirectory("${PAPERPAD_RECUT_LIB}/N64ModernRuntime" "${CMAKE_BINARY_DIR}/N64ModernRuntime")

# Vendored fmt cannot use consteval format strings under Apple clang; the
# fmt base.h guard (patches/n64recomp/fmt-consteval-guard.patch) honors this.
if (TARGET fmt)
    target_compile_definitions(fmt PUBLIC FMT_USE_CONSTEVAL=0)
endif()

add_library(RecompiledFuncs STATIC)
file(GLOB PM_FUNC_SOURCES "${PM_RECOMP_OUT}/*.c" "${PM_RECOMP_OUT}/*.cpp")
target_sources(RecompiledFuncs PRIVATE ${PM_FUNC_SOURCES})
target_compile_options(RecompiledFuncs PRIVATE
    $<$<C_COMPILER_ID:MSVC>:/bigobj>
    $<$<CXX_COMPILER_ID:MSVC>:/bigobj>
    $<$<NOT:$<C_COMPILER_ID:MSVC>>:-fno-strict-aliasing -Wno-unused-variable -Wno-implicit-function-declaration>
)
target_include_directories(RecompiledFuncs PRIVATE
    "${PM_RECOMP_OUT}"
    "${PAPERPAD_ROOT}/src"
    "${PAPERPAD_RECUT_LIB}/N64ModernRuntime/ultramodern/include"
    "${PAPERPAD_RECUT_LIB}/N64ModernRuntime/librecomp/include"
    "${PAPERPAD_RECUT_LIB}/N64ModernRuntime/N64Recomp/include"
)

find_package(SDL2 REQUIRED)

add_executable(PaperPad
    src/paperpad_main.cpp
    src/paperpad_paths.mm
    src/paper_rt64_context.cpp
    src/paper_stubs.cpp
    src/register_overlays.cpp
    src/builtin_texture_pack.cpp
    # Generated lookup table (provides get_entrypoint_address etc).
    "${PM_RECOMP_OUT}/lookup.cpp"
    # Paper Mario's aspMain audio microcode, recompiled from the local ROM.
    "${PM_GENERATED_RSP}"
)

if (APPLE)
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
    "${PAPERPAD_RECUT_LIB}/N64ModernRuntime/ultramodern/include"
    "${PAPERPAD_RECUT_LIB}/N64ModernRuntime/librecomp/include"
    "${PAPERPAD_RECUT_LIB}/N64ModernRuntime/N64Recomp/include"
    "${PAPERPAD_RECUT_LIB}/rt64/src/contrib"
    "${PAPERPAD_RECUT_LIB}/rt64/src/contrib/hlslpp/include"
    "${PAPERPAD_RECUT_LIB}/rt64/src"
    "${PAPERPAD_RECUT_LIB}/rt64/src/rhi"
    "${PAPERPAD_RECUT_LIB}/rt64/src/render"
    "${CMAKE_BINARY_DIR}/rt64/src"
)

target_link_libraries(PaperPad PRIVATE
    RecompiledFuncs
    librecomp
    ultramodern
    rt64
    SDL2::SDL2
)
