// Defines bool
#include <stdbool.h>
// Defines size_t
#include <stddef.h>

// Bigint

void *camlsnark_bn382_bigint_of_decimal_string(char *);

int camlsnark_bn382_bigint_num_limbs();

char *camlsnark_bn382_bigint_to_data(void *);

void *camlsnark_bn382_bigint_of_data(char *);

int camlsnark_bn382_bigint_bytes_per_limb();

void *camlsnark_bn382_bigint_div(void *, void *);

void *camlsnark_bn382_bigint_of_numeral(char *, int, int);

bool camlsnark_bn382_bigint_compare(void *, void *);

bool camlsnark_bn382_bigint_test_bit(void *, int);

void camlsnark_bn382_bigint_delete(void *);

void camlsnark_bn382_bigint_print(void *);

void *camlsnark_bn382_bigint_find_wnaf(size_t, void *);

// Fp

int camlsnark_bn382_fp_size_in_bits();

void *camlsnark_bn382_fp_size();

bool *camlsnark_bn382_fp_is_square(void *);

void *camlsnark_bn382_fp_sqrt(void *);

void *camlsnark_bn382_fp_random();

void *camlsnark_bn382_fp_of_int(int);

void *camlsnark_bn382_fp_inv(void *);

void *camlsnark_bn382_fp_square(void *);

void *camlsnark_bn382_fp_add(void *, void *);

void *camlsnark_bn382_fp_mul(void *, void *);

void *camlsnark_bn382_fp_sub(void *, void *);

void camlsnark_bn382_fp_mut_add(void *, void *);

void camlsnark_bn382_fp_mut_mul(void *, void *);

void camlsnark_bn382_fp_mut_sub(void *, void *);

void camlsnark_bn382_fp_copy(void *, void *);

void *camlsnark_bn382_fp_rng(int i);

void camlsnark_bn382_fp_delete(void *);

void camlsnark_bn382_fp_print(void *);

bool camlsnark_bn382_fp_equal(void *, void *);

void *camlsnark_bn382_fp_to_bigint(void *);

void *camlsnark_bn382_fp_of_bigint(void *);

// Fp vector

void *camlsnark_bn382_fp_vector_create();

int camlsnark_bn382_fp_vector_length(void *);

void camlsnark_bn382_fp_vector_emplace_back(void *, void *);

void *camlsnark_bn382_fp_vector_get(void *, int);

void camlsnark_bn382_fp_vector_delete(void *);

// Fq

int camlsnark_bn382_fq_size_in_bits();

void *camlsnark_bn382_fq_size();

bool *camlsnark_bn382_fq_is_square(void *);

void *camlsnark_bn382_fq_sqrt(void *);

void *camlsnark_bn382_fq_random();

void *camlsnark_bn382_fq_of_int(int);

void *camlsnark_bn382_fq_inv(void *);

void *camlsnark_bn382_fq_square(void *);

void *camlsnark_bn382_fq_add(void *, void *);

void *camlsnark_bn382_fq_mul(void *, void *);

void *camlsnark_bn382_fq_sub(void *, void *);

void camlsnark_bn382_fq_mut_add(void *, void *);

void camlsnark_bn382_fq_mut_mul(void *, void *);

void camlsnark_bn382_fq_mut_sub(void *, void *);

void camlsnark_bn382_fq_copy(void *, void *);

void *camlsnark_bn382_fq_rng(int i);

void camlsnark_bn382_fq_delete(void *);

void camlsnark_bn382_fq_print(void *);

bool camlsnark_bn382_fq_equal(void *, void *);

void *camlsnark_bn382_fq_to_bigint(void *);

void *camlsnark_bn382_fq_of_bigint(void *);

// Fq vector

void *camlsnark_bn382_fq_vector_create();

int camlsnark_bn382_fq_vector_length(void *);

void camlsnark_bn382_fq_vector_emplace_back(void *, void *);

void *camlsnark_bn382_fq_vector_get(void *, int);

void camlsnark_bn382_fq_vector_delete(void *);
