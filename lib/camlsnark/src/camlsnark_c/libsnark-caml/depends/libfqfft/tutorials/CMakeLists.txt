# Tutorials
add_executable(
  polynomial_multiplication
  EXCLUDE_FROM_ALL

  polynomial_multiplication_on_fft_example.cpp
)
target_link_libraries(
  polynomial_multiplication

  ${LIBFF_LIBRARIES}
)

add_executable(
  polynomial_evaluation
  EXCLUDE_FROM_ALL

  polynomial_evaluation_example.cpp
)
target_link_libraries(
  polynomial_evaluation

  ${LIBFF_LIBRARIES}
)

add_executable(
  lagrange_polynomial_evaluation
  EXCLUDE_FROM_ALL

  lagrange_polynomial_evaluation_example.cpp
)
target_link_libraries(
  lagrange_polynomial_evaluation

  ${LIBFF_LIBRARIES}
)