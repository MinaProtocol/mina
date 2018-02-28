#include <libsnark/caml/caml_mnt6.hpp>
#include <libsnark/gadgetlib1/gadgets/verifiers/r1cs_ppzksnark_verifier_gadget.hpp>

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

}
