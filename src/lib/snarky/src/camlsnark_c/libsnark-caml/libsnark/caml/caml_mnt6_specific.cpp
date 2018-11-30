#undef NDEBUG
#include <cassert>
#include <libsnark/caml/caml_mnt6.hpp>
#include <libsnark/gadgetlib1/gadgets/verifiers/r1cs_ppzksnark_verifier_gadget.hpp>
#include <libsnark/gadgetlib1/gadgets/verifiers/r1cs_se_ppzksnark_verifier_gadget.hpp>

extern "C" {
using namespace libsnark;

// verification key

void camlsnark_mnt6_emplace_bits_of_field(std::vector<bool>* v, FieldT &x) {
  size_t field_size = FieldT::size_in_bits();
  auto n = x.as_bigint();
  for (size_t i = 0; i < field_size; ++i) {
    v->emplace_back(n.test_bit(i));
  }
}

std::vector<bool>* camlsnark_mnt6_verification_key_other_to_bool_vector(
    r1cs_ppzksnark_verification_key<other_curve_ppT>* vk
) {
  return new std::vector<bool>(
      r1cs_ppzksnark_verification_key_variable<ppT>::get_verification_key_bits(*vk));
}

std::vector<FieldT>* camlsnark_mnt6_verification_key_other_to_field_vector(
    r1cs_ppzksnark_verification_key<other_curve_ppT>* r1cs_vk
) {
  const size_t input_size_in_elts = r1cs_vk->encoded_IC_query.rest.indices.size(); // this might be approximate for bound verification keys, however they are not supported by r1cs_ppzksnark_verification_key_variable
  const size_t vk_size_in_bits = r1cs_ppzksnark_verification_key_variable<ppT>::size_in_bits(input_size_in_elts);

  protoboard<FieldT> pb;
  pb_variable_array<FieldT> vk_bits;
  vk_bits.allocate(pb, vk_size_in_bits, "vk_bits");
  r1cs_ppzksnark_verification_key_variable<ppT> vk(pb, vk_bits, input_size_in_elts, "translation_step_vk");
  vk.generate_r1cs_witness(*r1cs_vk);

  return new std::vector<FieldT>(vk.all_vars.get_vals(pb));
}

// verification key variable
r1cs_ppzksnark_verification_key_variable<ppT>* camlsnark_mnt6_r1cs_ppzksnark_verification_key_variable_create(
    protoboard<FieldT>* pb,
    pb_variable_array<FieldT>* all_bits,
    int input_size) {
  return new r1cs_ppzksnark_verification_key_variable<ppT>(*pb, *all_bits, input_size, "verification_key_variable");
}

int camlsnark_mnt6_r1cs_ppzksnark_verification_key_variable_size_in_bits_for_input_size(int input_size) {
  return r1cs_ppzksnark_verification_key_variable<ppT>::size_in_bits(input_size);
}

void camlsnark_mnt6_r1cs_ppzksnark_verification_key_variable_delete(
    r1cs_ppzksnark_verification_key_variable<ppT>* vk) {
  delete vk;
}

void camlsnark_mnt6_r1cs_ppzksnark_verification_key_variable_generate_r1cs_constraints(
    r1cs_ppzksnark_verification_key_variable<ppT>* vk) {
  vk->generate_r1cs_constraints(false);
}

void camlsnark_mnt6_r1cs_ppzksnark_verification_key_variable_generate_r1cs_witness(
    r1cs_ppzksnark_verification_key_variable<ppT>* vkv,
    r1cs_ppzksnark_verification_key<other_curve_ppT>* vk) {
  vkv->generate_r1cs_witness(*vk);
}

// proof
r1cs_ppzksnark_proof_variable<ppT>* camlsnark_mnt6_r1cs_ppzksnark_proof_variable_create(
    protoboard<FieldT>* pb) {
  return new r1cs_ppzksnark_proof_variable<ppT>(*pb, "proof_variable");
}

void camlsnark_mnt6_r1cs_ppzksnark_proof_variable_delete(
    r1cs_ppzksnark_proof_variable<ppT>* p) {
  delete p;
}

void camlsnark_mnt6_r1cs_ppzksnark_proof_variable_generate_r1cs_constraints(
    r1cs_ppzksnark_proof_variable<ppT>* p) {
  p->generate_r1cs_constraints();
}

void camlsnark_mnt6_r1cs_ppzksnark_proof_variable_generate_r1cs_witness(
    r1cs_ppzksnark_proof_variable<ppT>* pv,
    r1cs_ppzksnark_proof<other_curve_ppT>* p) {
  pv->generate_r1cs_witness(*p);
}

// verifier
r1cs_ppzksnark_verifier_gadget<ppT>* camlsnark_mnt6_r1cs_ppzksnark_verifier_gadget_create(
    protoboard<FieldT>* pb,
    r1cs_ppzksnark_verification_key_variable<ppT>* vk,
    pb_variable_array<FieldT>* input,
    int elt_size,
    r1cs_ppzksnark_proof_variable<ppT>* proof,
    pb_variable<FieldT>* result) {
  return new r1cs_ppzksnark_verifier_gadget<ppT>(*pb, *vk, *input, elt_size, *proof, *result, "verifier_gadget");
}

void camlsnark_mnt6_r1cs_ppzksnark_verifier_gadget_delete(
    r1cs_ppzksnark_verifier_gadget<ppT>* g) {
  delete g;
}

void camlsnark_mnt6_r1cs_ppzksnark_verifier_gadget_generate_r1cs_constraints(
    r1cs_ppzksnark_verifier_gadget<ppT>* g) {
  g->generate_r1cs_constraints();
}

void camlsnark_mnt6_r1cs_ppzksnark_verifier_gadget_generate_r1cs_witness(
    r1cs_ppzksnark_verifier_gadget<ppT>* g) {
  g->generate_r1cs_witness();
}

// GM verifier gadget functions

// preprocessed verification key variable
r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>* 
camlsnark_mnt6_r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable_create_known(
    protoboard<FieldT>* pb,
    r1cs_se_ppzksnark_verification_key<other_curve<ppT>>* vk)
{
  return new r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>(
      *pb, *vk, "preprocessed_verification_key_variable");
}

r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>* 
camlsnark_mnt6_r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable_create()
{
  return new r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>();
}

void
camlsnark_mnt6_r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable_delete(
    r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>* vk)
{
    delete vk;
}

// verifier
r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>*
camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_verifier_gadget_create(
    protoboard<FieldT>* pb,
    r1cs_se_ppzksnark_verification_key_variable<ppT>* vk,
    pb_variable<FieldT>* accX,
    pb_variable<FieldT>* accY,
    r1cs_se_ppzksnark_proof_variable<ppT>* proof,
    pb_variable<FieldT>* result) {

  return new r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>(
      *pb, *vk, G1_variable<ppT>(*pb, *accX, *accY, "verifier acc"), *proof, *result,
      "se_verifier_gadget");
}

void camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_verifier_gadget_delete(
    r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>* g) {
  delete g;
}

void camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_verifier_gadget_generate_r1cs_constraints(
    r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>* g) {
  g->generate_r1cs_constraints();
}

void camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_verifier_gadget_generate_r1cs_witness(
    r1cs_se_ppzksnark_accumulated_verifier_gadget<ppT>* g) {
  g->generate_r1cs_witness();
}

// online verifier
r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>*
camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_online_verifier_gadget_create(
    protoboard<FieldT>* pb,
    r1cs_se_ppzksnark_preprocessed_r1cs_se_ppzksnark_verification_key_variable<ppT>* vk,
    pb_variable<FieldT>* accX,
    pb_variable<FieldT>* accY,
    r1cs_se_ppzksnark_proof_variable<ppT>* proof,
    pb_variable<FieldT>* result) {
  return new r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>(
      *pb, *vk, G1_variable<ppT>(*pb, *accX, *accY, "online verifier acc"), *proof, *result,
      "se_online_verifier_gadget");
}

void camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_online_verifier_gadget_delete(
    r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>* g) {
  delete g;
}

void camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_online_verifier_gadget_generate_r1cs_constraints(
    r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>* g) {
  g->generate_r1cs_constraints();
}

void camlsnark_mnt6_r1cs_se_ppzksnark_accumulated_online_verifier_gadget_generate_r1cs_witness(
    r1cs_se_ppzksnark_accumulated_online_verifier_gadget<ppT>* g) {
  g->generate_r1cs_witness();
}

// proof
r1cs_se_ppzksnark_proof_variable<ppT>* camlsnark_mnt6_r1cs_se_ppzksnark_proof_variable_create(
    protoboard<FieldT>* pb) {
  return new r1cs_se_ppzksnark_proof_variable<ppT>(*pb, "proof_variable");
}

void camlsnark_mnt6_r1cs_se_ppzksnark_proof_variable_delete(
    r1cs_se_ppzksnark_proof_variable<ppT>* p) {
  delete p;
}

void camlsnark_mnt6_r1cs_se_ppzksnark_proof_variable_generate_r1cs_constraints(
    r1cs_se_ppzksnark_proof_variable<ppT>* p) {
  p->generate_r1cs_constraints();
}

void camlsnark_mnt6_r1cs_se_ppzksnark_proof_variable_generate_r1cs_witness(
    r1cs_se_ppzksnark_proof_variable<ppT>* pv,
    r1cs_se_ppzksnark_proof<other_curve_ppT>* p) {
  pv->generate_r1cs_witness(*p);
}

// verification key variable
r1cs_se_ppzksnark_verification_key_variable <ppT>* 
camlsnark_mnt6_r1cs_se_ppzksnark_verification_key_variable_create(
    protoboard<FieldT>* pb,
    int input_size)
{
  return new r1cs_se_ppzksnark_verification_key_variable<ppT>(
      *pb, input_size, "se_verification_key_variable");
}

void
camlsnark_mnt6_r1cs_se_ppzksnark_verification_key_variable_delete(
    r1cs_se_ppzksnark_verification_key_variable<other_curve<ppT>>* vk)
{
    delete vk;
}

void
camlsnark_mnt6_r1cs_se_ppzksnark_verification_key_variable_generate_r1cs_witness(
    r1cs_se_ppzksnark_verification_key_variable<ppT>* vk,
    r1cs_se_ppzksnark_verification_key<other_curve<ppT>>* r1cs_vk
    )
{
    vk->generate_r1cs_witness(*r1cs_vk);
}

std::vector<linear_combination<FieldT>>* 
camlsnark_mnt6_r1cs_se_ppzksnark_verification_key_variable_characterizing_vars_up_to_sign(
    r1cs_se_ppzksnark_verification_key_variable<ppT>* vk
    )
{
    std::vector<linear_combination<FieldT>>* res = new std::vector< linear_combination<FieldT> >();

    // Get all the G1 X coordinates
    for (size_t i = 0; i < vk->all_G1_vars.size(); ++i) {
      res->emplace_back(vk->all_G1_vars[i]->X);
    }

    // Get all the G2 X coordinates
    for (size_t i = 0; i < vk->all_G2_vars.size(); ++i) {
      pb_linear_combination_array<FieldT> vars = vk->all_G2_vars[i]->X->all_vars;
      for (size_t j = 0; j < vars.size(); ++j) {
        res->emplace_back(vars[j]);
      }
    }

    // Get all the GT c0 coordinates
    for (size_t i = 0; i < vk->all_GT_vars.size(); ++i) {
      pb_linear_combination_array<FieldT> vars = vk->all_GT_vars[i]->c0.all_vars;
      for (size_t j = 0; j < vars.size(); ++j) {
        res->emplace_back(vars[j]);
      }
    }

    assert (res->size() ==
        vk->all_G1_vars.size() +
        vk->all_G2_vars.size() * Fqe_variable<ppT>::num_variables() +
        vk->all_GT_vars.size() * Fqe_variable<ppT>::num_variables() );

    return res;
}

// NB! These field elements MUST be unpacked fully (i.e., with not with choose_preimage)
std::vector<linear_combination<FieldT>>* 
camlsnark_mnt6_r1cs_se_ppzksnark_verification_key_variable_sign_vars(
    r1cs_se_ppzksnark_verification_key_variable<ppT>* vk
    )
{
    std::vector<linear_combination<FieldT>>* res = new std::vector< linear_combination<FieldT> >();

    // Get all the G1 Y coordinates.
    // We don't actually have to constrain these to be non-zero, but for ease
    // we will anyway because there are only a few of them.
    for (size_t i = 0; i < vk->all_G1_vars.size(); ++i) {
      res->emplace_back(vk->all_G1_vars[i]->Y);
    }

    // Get all the G2 Y.c0 coordinates. The analysis of why this is
    // correct is similar to what is discussed below.
    for (size_t i = 0; i < vk->all_G2_vars.size(); ++i) {
      res->emplace_back( vk->all_G2_vars[i]->Y->c0 );
    }

    // Say a GT variable is (c0, c1) =  c0 + W c1.
    // It must be unitary (since it will be equal to the output of a pairing) so it
    // satisfies
    //
    // (c0 + W c1) * (c0 - W c1) = 1
    // c0^2 - W^2 c1^2 =1
    // c1^2 = (c0^2 - 1)/W^2
    //
    // So c1 is determined up to sign by c0.
    //
    // c1 can be thought of as some vector of FieldT's, so assuming the first coordinate
    // of that vector is non-zero, its sign determines c1
    // (since its sign will be distinct in c1 and -c1)
    for (size_t i = 0; i < vk->all_GT_vars.size(); ++i) {
      res->emplace_back( vk->all_GT_vars[i]->c1.c0 );
    }

    assert (res->size() ==
        vk->all_G1_vars.size() +
        vk->all_G2_vars.size() +
        vk->all_GT_vars.size() );

    return res;
}

std::vector< libff::G1<other_curve<ppT>> >*
camlsnark_mnt6_gm_verification_key_other_query(
    r1cs_se_ppzksnark_verification_key<other_curve<ppT>> *vk)
{
    return new std::vector<libff::G1<other_curve<ppT>>>(vk->query);
}

std::vector< FieldT >*
camlsnark_mnt6_gm_verification_key_characterizing_elts_up_to_sign(
    r1cs_se_ppzksnark_verification_key<other_curve<ppT>> *vk)
{
    std::vector<libff::G1<other_curve<ppT>>> all_G1_elts = {};
    all_G1_elts.emplace_back(vk->query[0]);
    size_t input_size = vk->query.size() - 1;
    for (size_t i = 0; i < input_size; ++i) {
        all_G1_elts.emplace_back(vk->query[i+1]);
    }
    all_G1_elts.emplace_back(vk->G_alpha);
    all_G1_elts.emplace_back(vk->G_gamma);

    std::vector<libff::G2<other_curve<ppT>>> all_G2_elts = { vk->H, vk->H_beta, vk->H_gamma };
    std::vector<libff::Fqk<other_curve<ppT>>> all_GT_elts = { vk->G_alpha_H_beta.unitary_inverse() };

    std::vector<FieldT>* res = new std::vector<FieldT>();

    // Get all the G1 X coordinates
    for (size_t i = 0; i < all_G1_elts.size(); ++i) {
      all_G1_elts[i].to_affine_coordinates();
      res->emplace_back(all_G1_elts[i].X());
    }

    // Get all the G2 X coordinates
    for (size_t i = 0; i < all_G2_elts.size(); ++i) {
      all_G2_elts[i].to_affine_coordinates();
      std::vector<FieldT> elts = all_G2_elts[i].X().all_base_field_elements();
      for (size_t j = 0; j < elts.size(); ++j) {
        res->emplace_back(elts[j]);
      }
    }

    // Get all the GT c0 coordinates
    for (size_t i = 0; i < all_GT_elts.size(); ++i) {
      std::vector<FieldT> elts = all_GT_elts[i].c0.all_base_field_elements();
      for (size_t j = 0; j < elts.size(); ++j) {
        res->emplace_back(elts[j]);
      }
    }

    return res;
}

std::vector<FieldT>*
camlsnark_mnt6_gm_verification_key_sign_elts(
    r1cs_se_ppzksnark_verification_key<other_curve<ppT>> *vk)
{
    std::vector<libff::G1<other_curve<ppT>>> all_G1_elts = {};
    all_G1_elts.emplace_back(vk->query[0]);
    size_t input_size = vk->query.size() - 1;
    for (size_t i = 0; i < input_size; ++i) {
        all_G1_elts.emplace_back(vk->query[i+1]);
    }
    all_G1_elts.emplace_back(vk->G_alpha);
    all_G1_elts.emplace_back(vk->G_gamma);

    std::vector<libff::G2<other_curve<ppT>>> all_G2_elts = { vk->H, vk->H_beta, vk->H_gamma };
    std::vector<libff::Fqk<other_curve<ppT>>> all_GT_elts = { vk->G_alpha_H_beta.unitary_inverse() };

    std::vector<FieldT>* res = new std::vector<FieldT>();

    for (size_t i = 0; i < all_G1_elts.size(); ++i) {
      all_G1_elts[i].to_affine_coordinates();
      res->emplace_back(all_G1_elts[i].Y());
    }

    for (size_t i = 0; i < all_G2_elts.size(); ++i) {
      all_G2_elts[i].to_affine_coordinates();
      res->emplace_back(all_G2_elts[i].Y().c0);
    }

    for (size_t i = 0; i < all_GT_elts.size(); ++i) {
      res->emplace_back(all_GT_elts[i].c1.c0);
    }

    return res;
}

// End GM code

// Start g1 ops code

libff::G1<ppT>* camlsnark_mnt6_g1_of_coords (libff::Fq<ppT>* x, libff::Fq<ppT>* y) {
  return new libff::G1<ppT>(*x, *y);
}

libff::G1<ppT>* camlsnark_mnt6_g1_negate (libff::G1<ppT>* a) {
  return new libff::G1<ppT>(- *a);
}

libff::G1<ppT>* camlsnark_mnt6_g1_double (libff::G1<ppT>* a) {
  return new libff::G1<ppT>(a->dbl());
}

libff::G1<ppT>* camlsnark_mnt6_g1_add (libff::G1<ppT>* a, libff::G1<ppT>* b) {
  return new libff::G1<ppT>((*a) + (*b));
}

libff::G1<ppT>* camlsnark_mnt6_g1_scale (libff::bigint<libff::mnt6_r_limbs> *a, libff::G1<ppT>* x) {
  return new libff::G1<ppT>((*a) * (*x));
}

libff::G1<ppT>* camlsnark_mnt6_g1_scale_field (FieldT *a, libff::G1<ppT>* x) {
  return new libff::G1<ppT>((*a) * (*x));
}

libff::G1<ppT>* camlsnark_mnt6_g1_zero () {
  return new libff::G1<ppT>(libff::G1<ppT>::zero());
}

libff::G1<ppT>* camlsnark_mnt6_g1_one () {
  return new libff::G1<ppT>(libff::G1<ppT>::one());
}

void camlsnark_mnt6_g1_print(libff::G1<ppT>* x) {
  x->print();
}

bool camlsnark_mnt6_g1_equal(libff::G1<ppT>* a, libff::G1<ppT>* b) {
  return *a == *b;
}

void camlsnark_mnt6_g1_delete(libff::G1<ppT>* a) {
  delete a;
}

libff::G1<ppT>* camlsnark_mnt6_g1_random() {
  return new libff::G1<ppT>(libff::G1<ppT>::random_element());
}

void camlsnark_mnt6_g1_to_affine_coordinates(libff::G1<ppT>* a) {
  a->to_affine_coordinates();
}

libff::Fq<ppT>* camlsnark_mnt6_g1_x(libff::G1<ppT>* a) {
  assert(a->Z() == libff::Fq<ppT>::one());
  return new libff::Fq<ppT>(a->X());
}

libff::Fq<ppT>* camlsnark_mnt6_g1_y(libff::G1<ppT>* a) {
  assert(a->Z() == libff::Fq<ppT>::one());
  return new libff::Fq<ppT>(a->Y());
}

std::vector<libff::G1<ppT>>* camlsnark_mnt6_g1_vector_create() {
  return new std::vector<libff::G1<ppT>>();
}

int camlsnark_mnt6_g1_vector_length(std::vector<libff::G1<ppT>> *v) {
  return v->size();
}

void camlsnark_mnt6_g1_vector_emplace_back(std::vector<libff::G1<ppT>>* v, libff::G1<ppT>* x) {
  v->emplace_back(*x);
}

libff::G1<ppT>* camlsnark_mnt6_g1_vector_get(std::vector<libff::G1<ppT>>* v, int i) {
  libff::G1<ppT> res = (*v)[i];
  return new libff::G1<ppT>(res);
}

void camlsnark_mnt6_g1_vector_delete(std::vector<libff::G1<ppT>>* v) {
  delete v;
}

// ported from https://gitlab.com/robigalia/rust-bitmap/blob/master/src/lib.rs#L187, specialized to 3

libff::G1<ppT>* camlsnark_mnt6_g1_pedersen_inner(std::vector<libff::G1<ppT>>* params, unsigned char *bits, int bits_len, int offset, int triple_count) {
    size_t start_idx = (size_t)offset * 4;
    assert(triple_count * 3 <= bits_len * 8);
    assert(start_idx + triple_count*4 <= params->size());

    auto sum = libff::G1<ppT>::zero();

    #pragma omp declare reduction (G1_sum : libff::G1<ppT> : omp_out = omp_out + omp_in) initializer(omp_priv = omp_orig)
    #pragma omp parallel for reduction(G1_sum:sum)
    for (int i = 0; i < triple_count; i++) {
      unsigned char triple = bits[i];
      libff::G1<ppT> it = (*params)[start_idx + i*4 + (triple & 3)];
      if (triple & 4) {
          it = -it;
      }
      sum = sum + it;
    }
    return new libff::G1<ppT>(sum);
}

void camlsnark_mnt6_g2_delete(libff::G2<ppT>* a) {
  delete a;
}

void camlsnark_mnt6_g2_to_affine_coordinates(libff::G2<ppT>* a) {
  a->to_affine_coordinates();
}

std::vector<libff::Fq<ppT>>* camlsnark_mnt6_g2_x(libff::G2<ppT>* a) {
  assert(a->Z() == libff::Fqe<ppT>::one());
  return new std::vector< libff::Fq<ppT> >(a->X().all_base_field_elements());
}

std::vector<libff::Fq<ppT>>* camlsnark_mnt6_g2_y(libff::G2<ppT>* a) {
  assert(a->Z() == libff::Fqe<ppT>::one());
  return new std::vector< libff::Fq<ppT> >(a->Y().all_base_field_elements());
}

}
