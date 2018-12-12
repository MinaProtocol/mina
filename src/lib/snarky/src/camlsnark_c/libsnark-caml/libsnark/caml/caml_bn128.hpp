#include <libsnark/relations/variable.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/r1cs_ppzksnark/r1cs_ppzksnark.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/r1cs_se_ppzksnark/r1cs_se_ppzksnark.hpp>
#include <libsnark/zk_proof_systems/ppzksnark/r1cs_bg_ppzksnark/r1cs_bg_ppzksnark.hpp>
#include <libsnark/relations/constraint_satisfaction_problems/r1cs/r1cs.hpp>
#include <libsnark/gadgetlib1/pb_variable.hpp>
#include <libsnark/gadgetlib1/protoboard.hpp>
#include <libff/algebra/curves/bn128/bn128_pp.hpp>
#include <libff/algebra/curves/mnt/mnt6/mnt6_init.hpp>
#include <libff/common/rng.hpp>
#include <libff/algebra/fields/bigint.hpp>
#include <libff/algebra/scalar_multiplication/wnaf.hpp>
#include <gmp.h>
#include <openssl/md5.h>
#include <libsnark/gadgetlib1/gadgets/hashes/sha256/sha256_gadget.hpp>

typedef libff::bn128_pp ppT;
typedef libff::Fr<ppT> FieldT;
typedef ppT::G1_type G1;
typedef ppT::G2_type G2;
