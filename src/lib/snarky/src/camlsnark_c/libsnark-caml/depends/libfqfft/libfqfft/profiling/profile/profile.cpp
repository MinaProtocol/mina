/** @file
 *****************************************************************************

 Implementation of functions for profiler.

 *****************************************************************************
 * @author     This file is part of libfqfft, developed by SCIPR Lab
 *             and contributors (see AUTHORS).
 * @copyright  MIT license (see LICENSE file)
 *****************************************************************************/

#ifndef PROFILE_OP_COUNTS
#error PROFILE_OP_COUNTS must be defined to build this profiler.
#endif

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>
#include <sys/resource.h>
#include <unistd.h>

#include <libff/algebra/curves/edwards/edwards_pp.hpp>
#include <libff/common/double.hpp>
#include <omp.h>

#include <libfqfft/evaluation_domain/domains/arithmetic_sequence_domain.hpp>
#include <libfqfft/evaluation_domain/domains/basic_radix2_domain.hpp>
#include <libfqfft/evaluation_domain/domains/extended_radix2_domain.hpp>
#include <libfqfft/evaluation_domain/domains/geometric_sequence_domain.hpp>
#include <libfqfft/evaluation_domain/domains/step_radix2_domain.hpp>

using namespace libfqfft;

/* https://stackoverflow.com/questions/26237419/faster-than-rand */
static unsigned int seed = 5149;
inline int fastrand()
{
  seed = (214013 * seed + 2531011);
  return (seed >> 16) & 0x7FFF;
}

/*
 * @params:
 *   domain_sizes - size of the input vectors for specified domain
 *   profiling_type - vector specifing logging of runtime, memory, and operators
 *   path - vector specifying directory paths for logging our profiling_type
 *   type - vector of all domain types
 *   num_threads - number of threads
 *   key - specify which domain to profile on
 */
template <typename FieldT>
void profile(const std::string domain_sizes,
             const std::vector<int> profiling_type,
             const std::vector<std::string> path,
             const std::vector<std::string> type,
             const int num_threads,
             const int key)
{
  /* Determine domain sizes and precompute domain vectors */
  int n;
  std::vector<int> dom_sizes;
  std::stringstream domain_stream(domain_sizes);
  while (domain_stream >> n) dom_sizes.push_back(n);

  std::vector< std::vector<FieldT> > domain(dom_sizes.size());
  for (size_t i = 0; i < dom_sizes.size(); i++)
  {
    std::vector<FieldT> temp(dom_sizes[i]);
    for (size_t j = 0; j < dom_sizes[i]; j++)
      temp[j] = FieldT(fastrand());
    domain[i] = temp;
  }

  /* Runtime File */
  std::ofstream runtime_file;
  if (profiling_type[0])
  {
    runtime_file.open(path[0] + type[key] + "-" + std::to_string(num_threads) + ".csv");
    runtime_file << "size, time (in sec) \n";
  }
  /* Memory File */
  std::ofstream memory_file;
  if (profiling_type[1])
  {
    memory_file.open(path[1] + type[key] + "-" + std::to_string(num_threads) + ".csv");
    memory_file << "size, memory (in kilobytes) \n";
  }
  /* Operators File (only on single-thread case) */
  std::ofstream operators_file;
  if (profiling_type[2] && num_threads == 1)
  {
    operators_file.open(path[2] + type[key] + ".csv");
    operators_file << "size, addition, subtraction, multiplication, inverse \n";
  }

  printf("\n%s-%d\n", type[key].c_str(), num_threads);

  /* Assess on varying domain sizes */
  for (int s = 0; s < domain.size(); s++) {
    /* Initialization */
    std::vector<FieldT> a(domain[s]);
    const size_t n = a.size();

    if (num_threads == 1)
    {
      FieldT::add_cnt = 0;
      FieldT::sub_cnt = 0;
      FieldT::mul_cnt = 0;
      FieldT::inv_cnt = 0;
    }

    /* Start time */
    double start = omp_get_wtime();

    /* Perform operation */
    if (key == 0) basic_radix2_domain<FieldT>(n).FFT(a);
    else if (key == 1) extended_radix2_domain<FieldT>(n).FFT(a);
    else if (key == 2) step_radix2_domain<FieldT>(n).FFT(a);
    else if (key == 3) geometric_sequence_domain<FieldT>(n).FFT(a);
    else if (key == 4) arithmetic_sequence_domain<FieldT>(n).FFT(a);

    /* End time */
    double runtime = double(omp_get_wtime() - start);
    if (profiling_type[0]) runtime_file << n << "," << runtime << "\n";

    /* Memory usage */
    struct rusage r_usage;
    getrusage(RUSAGE_SELF, &r_usage);
    if (profiling_type[1]) memory_file << n << "," << r_usage.ru_maxrss << "\n";

    /* Operator count */
    if (profiling_type[2] && num_threads == 1)
      operators_file << n << ","
                     << FieldT::add_cnt << ","
                     << FieldT::sub_cnt << ","
                     << FieldT::mul_cnt << ","
                     << FieldT::inv_cnt << "\n";

    printf("%ld: %f seconds, %ld kilobytes\n", n, runtime, r_usage.ru_maxrss);
  }

  /* Close files */
  if (profiling_type[0]) runtime_file.close();
  if (profiling_type[1]) memory_file.close();
  if (profiling_type[2] && num_threads == 1) operators_file.close();
}

int main(int argc, char* argv[])
{
  if (argc < 6)
  {
    printf("./perform {key} {num_threads} {datetime} {profile_type} {domain_sizes}\n");
    printf("{key}: 0 - 5 \n{num_threads}: 1, 2, 4, 8 \n{datetime}: datetime\n");
    printf("{profile_type}: 0, 1, 2 \n{domain_sizes}: '32768 65536 131072 262144'\n");
    exit(0);
  }

  /* Parse input arguments */
  int key = atoi(argv[1]);
  int num_threads = atoi(argv[2]);
  std::string datetime = argv[3];
  std::string profile_type = argv[4];
  std::string domain_sizes = argv[5];

  /* Make log file directories */
  std::vector< std::string > path(3);
  path[0] = "libfqfft/profiling/logs/runtime/" + datetime + "/";
  path[1] = "libfqfft/profiling/logs/memory/" + datetime + "/";
  path[2] = "libfqfft/profiling/logs/operators/" + datetime + "/";

  /* Determine profiling type */
  int m;
  std::vector<int> profiling_type (3, 0);
  std::stringstream profiling_stream(profile_type);
  while (profiling_stream >> m) profiling_type[m - 1] = 1;
  if (profiling_type[0])
    if (system( ("mkdir -p " + path[0]).c_str() )) return 0;
  if (profiling_type[1])
    if (system( ("mkdir -p " + path[1]).c_str() )) return 0;
  if (profiling_type[2])
    if (system( ("mkdir -p " + path[2]).c_str() )) return 0;

  /* Domain types */
  std::vector< std::string > type;
  type.emplace_back("basic-radix2-fft");
  type.emplace_back("extended-radix2-fft");
  type.emplace_back("step-radix2-fft");
  type.emplace_back("geometric-fft");
  // type.emplace_back("arithmetic-fft");

  /* Profile on 1, 2, 4, or 8 threads */
  const int max_threads = omp_get_max_threads();
  if (num_threads >= 1 && num_threads <= max_threads)
  {
    /* Fix number of threads, no dynamic adjustment */
    omp_set_dynamic(0);
    omp_set_num_threads(num_threads);

#ifdef PROF_DOUBLE
    profile<libff::Double>(domain_sizes, profiling_type, path, type, num_threads, key);
#else
    libff::edwards_pp::init_public_params();
    profile<libff::Fr<libff::edwards_pp> >(domain_sizes, profiling_type, path, type, num_threads, key);
#endif
  }

  return 0;
}
