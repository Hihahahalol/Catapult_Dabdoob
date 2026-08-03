cmake_minimum_required(VERSION 3.14)
project(win32_helper LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 1. Output compiled binary directly into bin/ dir
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin")

# 2. download godot-cpp bindings (3.6 / 3.x branch) if missing
include(FetchContent)

FetchContent_Declare(
    godot-cpp
    GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
    GIT_TAG        3.6 # Targets Godot 3.6, update if required if project migrates to godot 4 or later.
)

# Fetch and build godot-cpp in background
FetchContent_MakeAvailable(godot-cpp)

# 3. Create the shared library target (.dll on Windows, .so on linux)
add_library(win32_helper SHARED
    native/win32_helper.cpp
)

# 4. Link against fetched godot-cpp library
target_link_libraries(win32_helper PRIVATE godot-cpp)

# 5. platform specific linking
if(WIN32)
    # Link Windows system API library for MonitorFromPoint / GetMonitorInfoW
    target_link_libraries(win32_helper PRIVATE user32)

    # Static runtime linking for MinGW GCC
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_link_options(win32_helper PRIVATE -static -static-libgcc -static-libstdc++)
    endif()
endif()