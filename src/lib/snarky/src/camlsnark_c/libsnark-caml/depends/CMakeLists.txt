add_subdirectory(gtest EXCLUDE_FROM_ALL)

find_package(OpenSSL REQUIRED)

if(${CURVE} STREQUAL "BN128")
  include_directories(ate-pairing/include)
  include_directories(xbyak)
  include_directories(${OPENSSL_INCLUDE_DIR})
  add_library(
    zm
    STATIC

    ate-pairing/src/zm.cpp
    ate-pairing/src/zm2.cpp
  )
  target_link_libraries(zm ${OPENSSL_LIBRARIES})
endif()

if("${WITH_SUPERCOP}")
  include_directories(libsnark-supercop/include)

  enable_language(ASM)

  file(GLOB_RECURSE SUPERCOP_SRCS libsnark-supercop/*.c libsnark-supercop/*.s)

  add_library(
    snark_supercop
    STATIC

    ${SUPERCOP_SRCS}
  )

  target_link_libraries(
    snark_supercop

    ${CRYPTO_LIBRARIES}
  )
endif()

OPTION(IS_LIBFF_PARENT OFF)
add_subdirectory(libff)

OPTION(IS_LIBFQFFT_PARENT OFF)
add_subdirectory(libfqfft)
