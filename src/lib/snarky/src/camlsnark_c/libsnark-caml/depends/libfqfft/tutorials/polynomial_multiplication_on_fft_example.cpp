#include <cstdio>
#include <vector>

#include <libff/common/double.hpp>
#include <libfqfft/polynomial_arithmetic/basic_operations.hpp>

using namespace libfqfft;

/* Polynomial Multiplication via FFT */
template <typename FieldT>
void polynomial_multiplication_on_FFT_example ()
{

  /* Polynomial a = 1 + 2x + 3x^2 + x^3 */
  std::vector<FieldT> a = { 1, 2, 3, 1 };

  /* Polynomial b = 1 + 2x + x^2 + x^3 */
  std::vector<FieldT> b = { 1, 2, 1, 1 };

  /*
   * c = a * b
   *   = (1 + 2x + 3x^2 + x^3) * (1 + 2x + x^2 + x^3)
   *   = 1 + 4x + 8x^2 + 10x^3 + 7x^4 + 4x^5 + x^6
   */
  std::vector<FieldT> c(1, FieldT::zero());
  _polynomial_multiplication(c, a, b);

  /* Print out the polynomial in human-readable form */
  for (size_t i = 0; i < c.size(); i++)
  {
    unsigned long coefficient = c[i].as_ulong();

    if (i == 0) std::cout << coefficient << " + ";
    else if (i < 6) std::cout << coefficient << "x^" << i << " + ";
    else std::cout << coefficient << "x^" << i << std::endl;
  }
}

int main()
{
  polynomial_multiplication_on_FFT_example<libff::Double> ();
}
