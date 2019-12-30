// Defines bool
#include <stdbool.h>
#include <stdint.h>
// Defines size_t
#include <stddef.h>

// usize vector

void *camlsnark_bn382_usize_vector_create();

int camlsnark_bn382_usize_vector_length(void *);

void camlsnark_bn382_usize_vector_emplace_back(void *, size_t);

size_t camlsnark_bn382_usize_vector_get(void *, int);

void camlsnark_bn382_usize_vector_delete(void *);

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

bool camlsnark_bn382_fp_is_square(void *);

void *camlsnark_bn382_fp_sqrt(void *);

void *camlsnark_bn382_fp_random();

void *camlsnark_bn382_fp_of_int(uint64_t);

char *camlsnark_bn382_fp_to_string(void *);

void *camlsnark_bn382_fp_inv(void *);

void *camlsnark_bn382_fp_square(void *);

void *camlsnark_bn382_fp_add(void *, void *);

void *camlsnark_bn382_fp_negate(void *);

void *camlsnark_bn382_fp_mul(void *, void *);

void *camlsnark_bn382_fp_div(void *, void *);

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

// Fp constraint matrix

void *camlsnark_bn382_fp_constraint_matrix_create();

void camlsnark_bn382_fp_constraint_matrix_append_row(void *, void*, void*);

void camlsnark_bn382_fp_constraint_matrix_delete(void *);

// Fp sponge

void *camlsnark_bn382_fp_sponge_params();

void camlsnark_bn382_fp_sponge_params_delete(void *);

void *camlsnark_bn382_fp_sponge_create();

void camlsnark_bn382_fp_sponge_delete(void *);

void camlsnark_bn382_fp_sponge_absorb(void *, void *, void *);

void *camlsnark_bn382_fp_sponge_squeeze(void *, void *);

// Fq

int camlsnark_bn382_fq_size_in_bits();

void *camlsnark_bn382_fq_size();

bool camlsnark_bn382_fq_is_square(void *);

void *camlsnark_bn382_fq_sqrt(void *);

void *camlsnark_bn382_fq_random();

void *camlsnark_bn382_fq_of_int(uint64_t);

char *camlsnark_bn382_fq_to_string(void *);

void *camlsnark_bn382_fq_inv(void *);

void *camlsnark_bn382_fq_square(void *);

void *camlsnark_bn382_fq_add(void *, void *);

void *camlsnark_bn382_fq_negate(void *);

void *camlsnark_bn382_fq_mul(void *, void *);

void *camlsnark_bn382_fq_div(void *, void *);

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

// Fq CsMat

void *camlsnark_bn382_fq_csmat_create(int, int);

void *camlsnark_bn382_fq_csmat_append_row(void *, void *, void *);

void camlsnark_bn382_fq_csmat_delete(void *);

// Fq constraint matrix

void *camlsnark_bn382_fq_constraint_matrix_create();

void camlsnark_bn382_fq_constraint_matrix_append_row(void *, void*, void*);

void camlsnark_bn382_fq_constraint_matrix_delete(void *);

// Fq sponge

void *camlsnark_bn382_fq_sponge_params();

void camlsnark_bn382_fq_sponge_params_delete(void *);

void *camlsnark_bn382_fq_sponge_create();

void camlsnark_bn382_fq_sponge_delete(void *);

void camlsnark_bn382_fq_sponge_absorb(void *, void *, void *);

void *camlsnark_bn382_fq_sponge_squeeze(void *, void *);

// Fp index

void *camlsnark_bn382_fp_index_create(void*, void*, void*, size_t, size_t);

void camlsnark_bn382_fp_index_delete(void *);

void *camlsnark_bn382_fp_index_a_row_comm(void*);
void *camlsnark_bn382_fp_index_a_col_comm(void*);
void *camlsnark_bn382_fp_index_a_val_comm(void*);

void *camlsnark_bn382_fp_index_b_row_comm(void*);
void *camlsnark_bn382_fp_index_b_col_comm(void*);
void *camlsnark_bn382_fp_index_b_val_comm(void*);

void *camlsnark_bn382_fp_index_c_row_comm(void*);
void *camlsnark_bn382_fp_index_c_col_comm(void*);
void *camlsnark_bn382_fp_index_c_val_comm(void*);

// Fp proof

void camlsnark_bn382_fp_proof_delete(void *);
void *camlsnark_bn382_fp_proof_create(void *, void* , void*);

void *camlsnark_bn382_fp_proof_w_comm(void *);
void *camlsnark_bn382_fp_proof_za_comm(void *);
void *camlsnark_bn382_fp_proof_zb_comm(void *);
void *camlsnark_bn382_fp_proof_h1_comm(void *);
void *camlsnark_bn382_fp_proof_g1_comm(void *);
void *camlsnark_bn382_fp_proof_h2_comm(void *);
void *camlsnark_bn382_fp_proof_g2_comm(void *);
void *camlsnark_bn382_fp_proof_h3_comm(void *);
void *camlsnark_bn382_fp_proof_g3_comm(void *);

void *camlsnark_bn382_fp_proof_proof1(void *);
void *camlsnark_bn382_fp_proof_proof2(void *);
void *camlsnark_bn382_fp_proof_proof3(void *);
void *camlsnark_bn382_fp_proof_sigma2(void *);
void *camlsnark_bn382_fp_proof_sigma3(void *);

void *camlsnark_bn382_fp_proof_w_eval(void *);
void *camlsnark_bn382_fp_proof_za_eval(void *);
void *camlsnark_bn382_fp_proof_zb_eval(void *);
void *camlsnark_bn382_fp_proof_h1_eval(void *);
void *camlsnark_bn382_fp_proof_g1_eval(void *);
void *camlsnark_bn382_fp_proof_h2_eval(void *);
void *camlsnark_bn382_fp_proof_g2_eval(void *);
void *camlsnark_bn382_fp_proof_h3_eval(void *);
void *camlsnark_bn382_fp_proof_g3_eval(void *);

void *camlsnark_bn382_fp_proof_row_evals_nocopy(void *);
void *camlsnark_bn382_fp_proof_col_evals_nocopy(void *);
void *camlsnark_bn382_fp_proof_val_evals_nocopy(void *);
void *camlsnark_bn382_fp_proof_evals_0(void *);
void *camlsnark_bn382_fp_proof_evals_1(void *);
void *camlsnark_bn382_fp_proof_evals_2(void *);

// G
void *camlsnark_bn382_g_one();
void *camlsnark_bn382_g_random();
void camlsnark_bn382_g_delete(void *);
void *camlsnark_bn382_g_add(void *, void *);
void *camlsnark_bn382_g_scale(void *, void *);
void *camlsnark_bn382_g_sub(void *, void *);
void *camlsnark_bn382_g_negate(void *);
void *camlsnark_bn382_g_to_affine(void *);
void *camlsnark_bn382_g_of_affine(void *);
void *camlsnark_bn382_g_of_affine_coordinates(void *, void*);
void *camlsnark_bn382_g_affine_x(void *);
void *camlsnark_bn382_g_affine_y(void *);
void camlsnark_bn382_g_affine_delete(void *);

// G1
void *camlsnark_bn382_g1_one();
void *camlsnark_bn382_g1_random();
void camlsnark_bn382_g1_delete(void *);
void *camlsnark_bn382_g1_add(void *, void *);
void *camlsnark_bn382_g1_scale(void *, void *);
void *camlsnark_bn382_g1_sub(void *, void *);
void *camlsnark_bn382_g1_negate(void *);
void *camlsnark_bn382_g1_to_affine(void *);
void *camlsnark_bn382_g1_of_affine(void *);
void *camlsnark_bn382_g1_of_affine_coordinates(void *, void*);
void *camlsnark_bn382_g1_affine_x(void *);
void *camlsnark_bn382_g1_affine_y(void *);
void camlsnark_bn382_g1_affine_delete(void *);
