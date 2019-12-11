// Defines bool
#include <stdbool.h>

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

// Fq vector

void *camlsnark_bn382_fq_vector_create();

int camlsnark_bn382_fq_vector_length(void *);

void camlsnark_bn382_fq_vector_emplace_back(void *, void *);

void *camlsnark_bn382_fq_vector_get(void *, int);

void camlsnark_bn382_fq_vector_delete(void *);
