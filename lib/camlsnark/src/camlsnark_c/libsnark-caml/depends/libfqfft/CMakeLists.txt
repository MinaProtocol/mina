cmake_minimum_required(VERSION 2.8)

project(libfqfft)

set(
  CURVE
  "BN128"
  CACHE
  STRING
  "Default curve: one of ALT_BN128, BN128, EDWARDS, MNT4, MNT6"
)

option(
  MULTICORE
  "Enable parallelized execution, using OpenMP"
  OFF
)

option(
  WITH_PROCPS
  "Use procps for memory profiling"
  ON
)

option(
  PROF_DOUBLE
  "Use Double for profiling"
  ON
)

option(
  IS_LIBFQFFT_PARENT
  "Install submodule dependencies if caller originates from here"
  ON
)

set(
  OPT_FLAGS
  ""
  CACHE
  STRING
  "Override C++ compiler optimization flags"
)

if(NOT "${ROOT_DEPENDS_DIR}" STREQUAL "")
  set(IS_PARENT_CMAKE OFF)
  set(DEPENDS_DIR "${ROOT_DEPENDS_DIR}")
elseif("${DEPENDS_DIR}" STREQUAL "")
  set(
    DEPENDS_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/depends"
    CACHE
    STRING
    "Optionally specify the dependency installation directory relative to the source directory (default: inside dependency folder)"
  )
else()
  set(DEPENDS_DIR "${DEPENDS_DIR}")
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
  # Common compilation flags and warning configuration
  set(
    CMAKE_CXX_FLAGS

    "${CMAKE_CXX_FLAGS} -std=c++11 -Wall -Wextra -Wfatal-errors -pthread"
  )

  if("${MULTICORE}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fopenmp")
  endif()

   # Default optimizations flags (to override, use -DOPT_FLAGS=...)
  if("${OPT_FLAGS}" STREQUAL "")
    set(
      OPT_FLAGS
      "-ggdb3 -O2 -march=native -mtune=native"
    )
  endif()
endif()

if("${MULTICORE}")
  add_definitions(-DMULTICORE=1)
endif()

set(
  CMAKE_CXX_FLAGS
  "${CMAKE_CXX_FLAGS} ${OPT_FLAGS}"
)

include(FindPkgConfig)
if("${WITH_PROCPS}")
  pkg_check_modules(
    PROCPS
    REQUIRED

    libprocps
  )
else()
  add_definitions(
    -DNO_PROCPS
  )
endif()

include_directories(.)

# GMP
find_path(GMP_INCLUDE_DIR NAMES gmp.h)
find_library(GMP_LIBRARIES NAMES gmp libgmp)
find_library(GMPXX_LIBRARIES NAMES gmpxx libgmpxx)

if ("${IS_LIBFQFFT_PARENT}")
  enable_testing()

  add_custom_target(
    tutorials

    COMMAND lagrange_polynomial_evaluation
    COMMAND polynomial_evaluation
    COMMAND polynomial_multiplication
  )

  # Add a `make check` target that builds and tests
  add_custom_target(check COMMAND ${CMAKE_CTEST_COMMAND})

  add_subdirectory(depends)
  add_subdirectory(libfqfft)
endif()
add_subdirectory(tutorials)
