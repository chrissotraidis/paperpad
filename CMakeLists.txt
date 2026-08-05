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
add_subdirectory("${PAPERPAD_RENDERER}" "${CMAKE_BINARY_DIR}/rt64")

# ---- Runtime: N64ModernRuntime (mstan fork, static mobile profile) ---------
set(N64MODERN_NO_DYNAMIC_CODE ON CACHE BOOL "Compile out runtime code generation" FORCE)
set(WITH_ARES_BRIDGE OFF CACHE BOOL "" FORCE)
set(RT64_BUILD_TOOLS ON CACHE BOOL "RT64 host tools" FORCE)
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

find_package(SDL2 REQUIRED)

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

if (APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
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
)

target_link_libraries(PaperPad PRIVATE
    RecompiledFuncs
    librecomp
    ultramodern
    rt64
    SDL2::SDL2
)
