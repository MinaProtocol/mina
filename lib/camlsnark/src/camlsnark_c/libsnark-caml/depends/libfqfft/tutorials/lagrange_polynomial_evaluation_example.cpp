#include <cstdio>
#include <memory>
#include <vector>

#include <libff/common/double.hpp>
#include <libfqfft/evaluation_domain/get_evaluation_domain.hpp>

using namespace libfqfft;

/* Lagrange Polynomial Evaluation */
template <typename FieldT>
void lagrange_polynomial_evaluation_example ()
{
  /* Domain size */
  const size_t m = 16;

  /* Evaluation element */
  FieldT t = FieldT(4);

  /* Get evaluation domain */
  std::shared_ptr<evaluation_domain<FieldT> > domain = get_evaluation_domain<FieldT>(m);

  /* Lagrange evaluation */
  std::vector<FieldT> a = domain->evaluate_all_lagrange_polynomials(t);

  for (size_t i = 0; i < a.size(); i++)
  {
    printf("%ld: %lu\n", i, a[i].as_ulong());
  }
}

int main()
{
  lagrange_polynomial_evaluation_example<libff::Double> ();
}
