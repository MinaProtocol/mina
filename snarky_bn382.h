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

void camlsnark_bn382_fp_mut_square(void *);

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

void camlsnark_bn382_fq_mut_square(void *);

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

// Fp oracles
void *camlsnark_bn382_fp_oracles_create(void*, void*);
void camlsnark_bn382_fp_oracles_delete(void*);

void* camlsnark_bn382_fp_oracles_alpha(void*);
void* camlsnark_bn382_fp_oracles_eta_a(void*);
void* camlsnark_bn382_fp_oracles_eta_b(void*);
void* camlsnark_bn382_fp_oracles_eta_c(void*);
void* camlsnark_bn382_fp_oracles_beta1(void*);
void* camlsnark_bn382_fp_oracles_beta2(void*);
void* camlsnark_bn382_fp_oracles_beta3(void*);
void* camlsnark_bn382_fp_oracles_batch(void*);
void* camlsnark_bn382_fp_oracles_r(void*);
void* camlsnark_bn382_fp_oracles_r_k(void*);
void* camlsnark_bn382_fp_oracles_x_hat_beta1(void*);
void* camlsnark_bn382_fp_oracles_digest_before_evaluations(void*);

// Fq oracles
void *camlsnark_bn382_fq_oracles_create(void*, void*);
void camlsnark_bn382_fq_oracles_delete(void*);

void* camlsnark_bn382_fq_oracles_opening_prechallenges(void*);
void* camlsnark_bn382_fq_oracles_alpha(void*);
void* camlsnark_bn382_fq_oracles_eta_a(void*);
void* camlsnark_bn382_fq_oracles_eta_b(void*);
void* camlsnark_bn382_fq_oracles_eta_c(void*);
void* camlsnark_bn382_fq_oracles_beta1(void*);
void* camlsnark_bn382_fq_oracles_beta2(void*);
void* camlsnark_bn382_fq_oracles_beta3(void*);
void* camlsnark_bn382_fq_oracles_polys(void*);
void* camlsnark_bn382_fq_oracles_evals(void*);
void* camlsnark_bn382_fq_oracles_digest_before_evaluations(void*);
void* camlsnark_bn382_fq_oracles_x_hat_nocopy(void*);

// Fp verifier index
void *camlsnark_bn382_fp_verifier_index_create(void*);
void camlsnark_bn382_fp_verifier_index_delete(void*);
void *camlsnark_bn382_fp_verifier_index_urs(void*);

void *camlsnark_bn382_fp_verifier_index_make(
    size_t, size_t, size_t, size_t, size_t,
    void*,
    void*, void*, void*, void*,
    void*, void*, void*, void*,
    void*, void*, void*, void* );

// Fq verifier index
void *camlsnark_bn382_fq_verifier_index_create(void*);
void camlsnark_bn382_fq_verifier_index_delete(void*);
void *camlsnark_bn382_fq_verifier_index_urs(void*);

void *camlsnark_bn382_fq_verifier_index_make(
    size_t, size_t, size_t, size_t, size_t,
    void*,
    void*, void*, void*, void*,
    void*, void*, void*, void*,
    void*, void*, void*, void* );

// Fp URS
void *camlsnark_bn382_fp_urs_create(size_t);
void camlsnark_bn382_fp_urs_write(void*, char*);
void* camlsnark_bn382_fp_urs_read(char*);
void* camlsnark_bn382_fp_urs_lagrange_commitment(void*, size_t, size_t);
void* camlsnark_bn382_fp_urs_commit_evaluations(void*, size_t, void*);
void* camlsnark_bn382_fp_urs_dummy_opening_check(void*);
void* camlsnark_bn382_fp_urs_dummy_degree_bound_checks(void*, void*);

// Fq URS
void *camlsnark_bn382_fq_urs_create(size_t);
void camlsnark_bn382_fq_urs_write(void*, char*);
void* camlsnark_bn382_fq_urs_read(char*);
void* camlsnark_bn382_fq_urs_lagrange_commitment(void*, size_t, size_t);
void* camlsnark_bn382_fq_urs_commit_evaluations(void*, size_t, void*);
void* camlsnark_bn382_fq_urs_b_poly_commitment(void*, void*);
void* camlsnark_bn382_fq_urs_h(void*);

// Fp index

size_t camlsnark_bn382_fp_index_domain_h_size(void*);
size_t camlsnark_bn382_fp_index_domain_k_size(void*);

void *camlsnark_bn382_fp_index_create(void*, void*, void*, size_t, size_t, void*);

void camlsnark_bn382_fp_index_delete(void *);

void *camlsnark_bn382_fp_index_a_row_comm(void*);
void *camlsnark_bn382_fp_index_a_col_comm(void*);
void *camlsnark_bn382_fp_index_a_val_comm(void*);
void *camlsnark_bn382_fp_index_a_rc_comm(void*);

void *camlsnark_bn382_fp_index_b_row_comm(void*);
void *camlsnark_bn382_fp_index_b_col_comm(void*);
void *camlsnark_bn382_fp_index_b_val_comm(void*);
void *camlsnark_bn382_fp_index_b_rc_comm(void*);

void *camlsnark_bn382_fp_index_c_row_comm(void*);
void *camlsnark_bn382_fp_index_c_col_comm(void*);
void *camlsnark_bn382_fp_index_c_val_comm(void*);
void *camlsnark_bn382_fp_index_c_rc_comm(void*);

size_t camlsnark_bn382_fp_index_num_variables(void*);
size_t camlsnark_bn382_fp_index_public_inputs(void*);
size_t camlsnark_bn382_fp_index_nonzero_entries(void*);
size_t camlsnark_bn382_fp_index_max_degree(void*);

// Fq index

size_t camlsnark_bn382_fq_index_domain_h_size(void*);
size_t camlsnark_bn382_fq_index_domain_k_size(void*);

void *camlsnark_bn382_fq_index_create(void*, void*, void*, size_t, size_t, void*);

void camlsnark_bn382_fq_index_delete(void *);

void *camlsnark_bn382_fq_index_a_row_comm(void*);
void *camlsnark_bn382_fq_index_a_col_comm(void*);
void *camlsnark_bn382_fq_index_a_val_comm(void*);
void *camlsnark_bn382_fq_index_a_rc_comm(void*);

void *camlsnark_bn382_fq_index_b_row_comm(void*);
void *camlsnark_bn382_fq_index_b_col_comm(void*);
void *camlsnark_bn382_fq_index_b_val_comm(void*);
void *camlsnark_bn382_fq_index_b_rc_comm(void*);

void *camlsnark_bn382_fq_index_c_row_comm(void*);
void *camlsnark_bn382_fq_index_c_col_comm(void*);
void *camlsnark_bn382_fq_index_c_val_comm(void*);
void *camlsnark_bn382_fq_index_c_rc_comm(void*);

size_t camlsnark_bn382_fq_index_num_variables(void*);
size_t camlsnark_bn382_fq_index_public_inputs(void*);
size_t camlsnark_bn382_fq_index_nonzero_entries(void*);
size_t camlsnark_bn382_fq_index_max_degree(void*);

// Fp proof

void camlsnark_bn382_fp_proof_delete(void *);
void *camlsnark_bn382_fp_proof_create(void *, void* , void*);
void *camlsnark_bn382_fp_proof_make(void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *,void *);

void *camlsnark_bn382_fp_proof_w_comm(void *);
void *camlsnark_bn382_fp_proof_za_comm(void *);
void *camlsnark_bn382_fp_proof_zb_comm(void *);
void *camlsnark_bn382_fp_proof_h1_comm(void *);
void *camlsnark_bn382_fp_proof_h2_comm(void *);
void *camlsnark_bn382_fp_proof_h3_comm(void *);

void *camlsnark_bn382_fp_proof_g1_comm_nocopy(void *);
void *camlsnark_bn382_fp_proof_g2_comm_nocopy(void *);
void *camlsnark_bn382_fp_proof_g3_comm_nocopy(void *);

void *camlsnark_bn382_fp_proof_commitment_with_degree_bound_0(void *);
void *camlsnark_bn382_fp_proof_commitment_with_degree_bound_1(void *);

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
void *camlsnark_bn382_fp_proof_rc_evals_nocopy(void *);

void *camlsnark_bn382_fp_proof_evals_0(void *);
void *camlsnark_bn382_fp_proof_evals_1(void *);
void *camlsnark_bn382_fp_proof_evals_2(void *);

// Fq proof

void camlsnark_bn382_fq_proof_delete(void *);
void *camlsnark_bn382_fq_proof_create(void *, void* , void*, void*, void*);
void *camlsnark_bn382_fq_proof_make(
    void*,
    void*, void*, void*,
    void*, void*, void*,
    void*, void*, void*,
    void*, void*, void*,

    void*, void*,

    void*, void*, void*, void*, void*,

    void*, void*, void*,
    void*, void*
);

void *camlsnark_bn382_fq_proof_w_comm(void *);
void *camlsnark_bn382_fq_proof_za_comm(void *);
void *camlsnark_bn382_fq_proof_zb_comm(void *);
void *camlsnark_bn382_fq_proof_h1_comm(void *);
void *camlsnark_bn382_fq_proof_h2_comm(void *);
void *camlsnark_bn382_fq_proof_h3_comm(void *);

void *camlsnark_bn382_fq_proof_g1_comm_nocopy(void *);
void *camlsnark_bn382_fq_proof_g2_comm_nocopy(void *);
void *camlsnark_bn382_fq_proof_g3_comm_nocopy(void *);

void *camlsnark_bn382_fq_proof_evals_nocopy(void *);

void *camlsnark_bn382_fq_proof_proof(void *);

void *camlsnark_bn382_fq_proof_sigma2(void *);
void *camlsnark_bn382_fq_proof_sigma3(void *);

// Fq proof evaluations

void *camlsnark_bn382_fq_proof_evaluations_w(void *);
void *camlsnark_bn382_fq_proof_evaluations_za(void *);
void *camlsnark_bn382_fq_proof_evaluations_zb(void *);
void *camlsnark_bn382_fq_proof_evaluations_h1(void *);
void *camlsnark_bn382_fq_proof_evaluations_h2(void *);
void *camlsnark_bn382_fq_proof_evaluations_h3(void *);
void *camlsnark_bn382_fq_proof_evaluations_g1(void *);
void *camlsnark_bn382_fq_proof_evaluations_g2(void *);
void *camlsnark_bn382_fq_proof_evaluations_g3(void *);

void *camlsnark_bn382_fq_proof_evaluations_make(
    void *, void *, void *,
    void *, void *, void *,
    void *, void *, void *,
    void *, void *, void *,
    void *, void *, void *,
    void *, void *, void *,
    void *, void *, void *
);

void *camlsnark_bn382_fq_proof_evaluations_row_nocopy(void *);
void *camlsnark_bn382_fq_proof_evaluations_col_nocopy(void *);
void *camlsnark_bn382_fq_proof_evaluations_val_nocopy(void *);
void *camlsnark_bn382_fq_proof_evaluations_rc_nocopy(void *);

void *camlsnark_bn382_fq_proof_evaluations_triple_0(void *);
void *camlsnark_bn382_fq_proof_evaluations_triple_1(void *);
void *camlsnark_bn382_fq_proof_evaluations_triple_2(void *);

// Fq opening proof
void *camlsnark_bn382_fq_opening_proof_lr(void *);
void *camlsnark_bn382_fq_opening_proof_z1(void *);
void *camlsnark_bn382_fq_opening_proof_z2(void *);
void *camlsnark_bn382_fq_opening_proof_delta(void *);
void *camlsnark_bn382_fq_opening_proof_sg(void *);

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
void *camlsnark_bn382_g_affine_create(void *, void*);
void *camlsnark_bn382_g_affine_x(void *);
void *camlsnark_bn382_g_affine_y(void *);
void camlsnark_bn382_g_affine_delete(void *);

void *camlsnark_bn382_g_affine_vector_create();
int camlsnark_bn382_g_affine_vector_length(void *);
void camlsnark_bn382_g_affine_vector_emplace_back(void *, void *);
void *camlsnark_bn382_g_affine_vector_get(void *, int);
void camlsnark_bn382_g_affine_vector_delete(void *);

void *camlsnark_bn382_g_affine_pair_0(void *);
void *camlsnark_bn382_g_affine_pair_1(void *);
void *camlsnark_bn382_g_affine_pair_make(void *, void*);

void *camlsnark_bn382_g_affine_pair_vector_create();
int camlsnark_bn382_g_affine_pair_vector_length(void *);
void camlsnark_bn382_g_affine_pair_vector_emplace_back(void *, void *);
void *camlsnark_bn382_g_affine_pair_vector_get(void *, int);
void camlsnark_bn382_g_affine_pair_vector_delete(void *);

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
void *camlsnark_bn382_g1_affine_create(void *, void*);
void *camlsnark_bn382_g1_affine_x(void *);
void *camlsnark_bn382_g1_affine_y(void *);
void camlsnark_bn382_g1_affine_delete(void *);

void *camlsnark_bn382_g1_affine_vector_create();
int camlsnark_bn382_g1_affine_vector_length(void *);
void camlsnark_bn382_g1_affine_vector_emplace_back(void *, void *);
void *camlsnark_bn382_g1_affine_vector_get(void *, int);
void camlsnark_bn382_g1_affine_vector_delete(void *);

void *camlsnark_bn382_g1_affine_pair_0(void *);
void *camlsnark_bn382_g1_affine_pair_1(void *);
void *camlsnark_bn382_g1_affine_pair_make(void *, void *);

void *camlsnark_bn382_g1_affine_pair_vector_create();
int camlsnark_bn382_g1_affine_pair_vector_length(void *);
void camlsnark_bn382_g1_affine_pair_vector_emplace_back(void *, void *);
void *camlsnark_bn382_g1_affine_pair_vector_get(void *, int);
void camlsnark_bn382_g1_affine_pair_vector_delete(void *);

// Fq triple
void *camlsnark_bn382_fq_triple_0(void *);
void *camlsnark_bn382_fq_triple_1(void *);
void *camlsnark_bn382_fq_triple_2(void *);
