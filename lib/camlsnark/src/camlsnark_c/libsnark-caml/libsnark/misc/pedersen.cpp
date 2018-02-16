#include <libff/algebra/curves/mnt/mnt4/mnt4_pp.hpp>
#include <libff/algebra/curves/mnt/mnt6/mnt6_pp.hpp>
#include <libff/algebra/curves/mnt/mnt4/mnt4_init.hpp>
#include <libff/algebra/curves/mnt/mnt6/mnt6_init.hpp>
#include <time.h>

typedef libff::mnt4_pp ppT;
typedef libff::mnt6_pp inner_curveT;

typedef inner_curveT::G1_type G1_inner;
typedef inner_curveT::Fq_type Fq;
typedef inner_curveT::Fp_type Fr;

typedef libff::bigint<libff::mnt6_q_limbs> coordinate_bigint;
typedef libff::bigint<libff::mnt6_r_limbs> scalar;
typedef Fr scalar_field;

typedef libff::Fr<ppT> FieldT;

struct signature {
  scalar s;
  scalar e;
};

struct hash_state {
  size_t bits_consumed;
  G1_inner acc;
};

// G1 is a curve with order |Fr| over Fq

// TODO: It's bad if there's ever something hashing to zero, I guess
// we assume that can't happen since that would be a hash collision.
void update_with_bits(
    std::vector<G1_inner> &coeffs,
    hash_state &state,
    std::vector<bool> &input) {

  auto shift = state.bits_consumed;
  auto n = input.size();
  auto acc = state.acc;
  for (int i = 0; i < n; ++i) {
    if (input[i]) {
      acc = acc + coeffs[i + shift];
    }
  }
  state.acc = acc;
  state.bits_consumed += n;
}

void update_with_g1(
    std::vector<G1_inner> &coeffs,
    hash_state &state,
    G1_inner &p) {

  p.to_affine_coordinates();

  coordinate_bigint X = p.X().as_bigint();
  coordinate_bigint Y = p.X().as_bigint();

  auto acc = state.acc;
  auto shift = state.bits_consumed;
  // Probably don't need to update with both X and Y actually
  auto n = Fr::size_in_bits();
  for (int i = 0; i < n; ++i) {
    if (X.test_bit(i)) {
      acc = acc + coeffs[shift + i];
    }
    if (Y.test_bit(i)) {
      acc = acc + coeffs[shift + n + i];
    }
  }
  state.acc = acc;
  state.bits_consumed += 2 * n;
}

std::vector<bool> digest_bits(hash_state &state) {
  auto acc = state.acc;
  acc.to_affine_coordinates();
  coordinate_bigint X = acc.X().as_bigint();

  size_t n = Fq::size_in_bits();
  auto bits = std::vector<bool> ();
  // Wonder if interleaving is faster? Might try that since
  // moving the bits around is "free" in the snark
  for (size_t i = 0; i < n; ++i) {
    bits.emplace_back(X.test_bit(i));
  }
  /*
  coordinate_bigint Y = acc.Y().as_bigint();
  for (size_t i = 0; i < n; ++i) {
    bits.emplace_back(Y.test_bit(i));
  } */

  return bits;
}

// I believe this is safe because the two fields have the same size in bits.
scalar digest_scalar(hash_state &state) {
  auto acc = state.acc;
  acc.to_affine_coordinates();
  coordinate_bigint X = acc.X().as_bigint();
  return X;
}

signature schnorr_sign(
    std::vector<G1_inner> &coeffs,
    scalar &sk,
    std::vector<bool> &msg) {
  scalar_field x = scalar_field(sk);

  scalar_field k_f = scalar_field::random_element();
  scalar k = k_f.as_bigint();
  
  G1_inner r = k * G1_inner::one();

  hash_state state;
  state.bits_consumed = 0;
  state.acc = G1_inner::one();

  update_with_g1(coeffs, state, r);
  update_with_bits(coeffs, state, msg);

  scalar_field e = scalar(digest_scalar(state));
  scalar_field s = k_f - x * e;
  signature sig;
  sig.s = s.as_bigint();
  sig.e = e.as_bigint();
  return sig;
}

scalar schnorr_secret_key() {
  return scalar_field::random_element().as_bigint();
}

G1_inner schnorr_public_key(scalar &sk) {
  return sk * G1_inner::one();
}

bool schnorr_verify(
    std::vector<G1_inner> &coeffs,
    G1_inner &pk,
    std::vector<bool> &msg,
    signature &sig) {
  G1_inner r = sig.s * G1_inner::one() + sig.e * pk;

  hash_state state;
  state.bits_consumed = 0;
  state.acc = G1_inner::one();

  update_with_g1(coeffs, state, r);
  update_with_bits(coeffs, state, msg);
  scalar e = digest_scalar(state);

  return e == sig.e;
}

extern "C" {
void camlsnark_pedersen_test(int max_input_size, int message_length) {
  scalar sk = schnorr_secret_key();
  G1_inner pk = schnorr_public_key(sk);

  auto coeffs = std::vector<G1_inner>();

  for (int i = 0; i < max_input_size; ++i) {
    auto c = scalar_field::random_element().as_bigint() * G1_inner::one();
    coeffs.emplace_back(c);
  }

  int count = 1000;

  auto messages = std::vector<std::vector<bool>>();
  for (int j = 0; j < count; ++j) {
    auto msg = std::vector<bool>();
    for (int i = 0; i < message_length; ++i) {
      msg.emplace_back(rand() % 2 == 0);
    }
    messages.emplace_back(msg);
  }

  auto signatures = std::vector<signature>();
  for (int j = 0; j < count; ++j) {
    signature sig = schnorr_sign(coeffs, sk, messages[j]);
    signatures.emplace_back(sig);
  }

  clock_t t = clock();
  for (int i = 0; i < count; ++i) {
    schnorr_verify(coeffs, pk, messages[i], signatures[i]);
  }
  t = clock() - t;
  printf("Signature verified avg in %f seconds\n", ((float) t)/CLOCKS_PER_SEC / count);
}

}
