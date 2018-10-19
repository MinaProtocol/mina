#include <cstdio>
#include <memory>
#include <vector>

#include <libff/common/double.hpp>
#include <libfqfft/evaluation_domain/get_evaluation_domain.hpp>

using namespace libfqfft;

/* Polynomial Evaluation */
template <typename FieldT>
void polynomial_evaluation_example ()
{
  /* Domain size */
  size_t m = 4;

  /* Evaluation vector */
  std::vector<FieldT> f = { 2, 5, 3, 8 };

  /* Get evaluation domain */
  std::shared_ptr<evaluation_domain<FieldT> > domain = get_evaluation_domain<FieldT>(m);

  /* FFT */
  domain->FFT(f);

  for (size_t i = 0; i < f.size(); i++)
  {
    printf("%ld: %ld\n", i, f[i].as_ulong());
  }
}

int main()
{
  polynomial_evaluation_example<libff::Double> ();
}
