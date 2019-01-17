add_subdirectory(gtest EXCLUDE_FROM_ALL)

if(${CURVE} STREQUAL "BN128")
  include_directories(ate-pairing/include)
  include_directories(xbyak)
  add_library(
    zm
    STATIC

    ate-pairing/src/zm.cpp
    ate-pairing/src/zm2.cpp
  )
endif()

OPTION(IS_LIBFF_PARENT OFF)
add_subdirectory(libff)
