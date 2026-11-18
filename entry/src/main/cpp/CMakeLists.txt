cmake_minimum_required(VERSION 3.5.0)
project(diskinfo)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH})

add_library(diskinfo SHARED
    napi_init.cpp
    core/cdi_interpret.cpp
    core/cdi_json.cpp
)

target_compile_features(diskinfo PUBLIC cxx_std_17)

target_link_libraries(diskinfo PUBLIC libace_napi.z.so)
