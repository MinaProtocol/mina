install(
  DIRECTORY "" DESTINATION "include/libfqfft"
  FILES_MATCHING
  PATTERN "*.hpp"
  PATTERN "*.tcc"
  PATTERN "logs" EXCLUDE
  PATTERN "tests" EXCLUDE
  PATTERN "tutorials" EXCLUDE
)

# Profiling with Double by default
add_executable(
  profiling_menu
  EXCLUDE_FROM_ALL

  profiling/profiling_menu.cpp
)
set_target_properties(
  profiling_menu

  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY
  ${CMAKE_HOME_DIRECTORY}
)

add_executable(
  profiler
  EXCLUDE_FROM_ALL

  profiling/profile/profile.cpp
)
target_compile_definitions(
  profiler

  PUBLIC
  -DPROFILE_OP_COUNTS
  -DMULTICORE
)
set_target_properties(
  profiler

  PROPERTIES
  COMPILE_FLAGS "-fopenmp"
  LINK_FLAGS "-fopenmp"
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_HOME_DIRECTORY}
)
target_link_libraries(
  profiler

  ff
  ${GMP_LIBRARIES}
  ${GMPXX_LIBRARIES}
  ${PROCPS_LIBRARIES}
)
target_include_directories(
  profiler

  PUBLIC
  ${DEPENDS_DIR}/libff/
)

if(${PROF_DOUBLE})
  target_compile_definitions(
    profiling_menu
    PUBLIC -DPROF_DOUBLE
  )
  target_compile_definitions(
    profiler
    PUBLIC -DPROF_DOUBLE
  )
endif()

if ("${IS_LIBFQFFT_PARENT}")
  # Tests
  add_executable(
    evaluation_domain_test
    EXCLUDE_FROM_ALL

    tests/init_test
    tests/evaluation_domain_test
  )
  target_link_libraries(
    evaluation_domain_test

    ff
    gtest_main
  )
  target_include_directories(
    evaluation_domain_test

    PUBLIC
    ${DEPENDS_DIR}/libff/
  )

  add_executable(
    polynomial_arithmetic_test
    EXCLUDE_FROM_ALL

    tests/init_test
    tests/polynomial_arithmetic_test
  )
  target_link_libraries(
    polynomial_arithmetic_test

    ff
    gtest_main
  )
  target_include_directories(
    polynomial_arithmetic_test

    PUBLIC
    ${DEPENDS_DIR}/libff/
  )

  add_executable(
    kronecker_substitution_test
    EXCLUDE_FROM_ALL

    tests/init_test
    tests/kronecker_substitution_test
  )
  target_link_libraries(
    kronecker_substitution_test

    ff
    gtest_main
  )
  target_include_directories(
    kronecker_substitution_test

    PUBLIC
    ${DEPENDS_DIR}/libff/
  )

  include(CTest)
  add_test(
    NAME evaluation_domain_test
    COMMAND evaluation_domain_test
  )
  add_test(
    NAME polynomial_arithmetic_test
    COMMAND polynomial_arithmetic_test
  )
  add_test(
    NAME kronecker_substitution_test
    COMMAND kronecker_substitution_test
  )

  add_dependencies(check evaluation_domain_test)
  add_dependencies(check polynomial_arithmetic_test)
  add_dependencies(check kronecker_substitution_test)
endif()
