module Types = Marlin_plonk_bindings_types

(** Biginteger types *)

module Bigint_256 = Marlin_plonk_bindings_bigint_256
module Bigint_384 = Marlin_plonk_bindings_bigint_384

(** Finite fields *)

module Pasta_fp = Marlin_plonk_bindings_pasta_fp
module Pasta_fq = Marlin_plonk_bindings_pasta_fq
module Tweedle_fp = Marlin_plonk_bindings_tweedle_fp
module Tweedle_fq = Marlin_plonk_bindings_tweedle_fq
module Bn_382_fp = Marlin_plonk_bindings_bn_382_fp
module Bn_382_fq = Marlin_plonk_bindings_bn_382_fq

(* Finite field vectors *)

module Pasta_fp_vector = Marlin_plonk_bindings_pasta_fp_vector
module Pasta_fq_vector = Marlin_plonk_bindings_pasta_fq_vector
module Tweedle_fp_vector = Marlin_plonk_bindings_tweedle_fp_vector
module Tweedle_fq_vector = Marlin_plonk_bindings_tweedle_fq_vector
module Bn_382_fp_vector = Marlin_plonk_bindings_bn_382_fp_vector
module Bn_382_fq_vector = Marlin_plonk_bindings_bn_382_fq_vector

(* Groups *)

module Pasta_vesta = Marlin_plonk_bindings_pasta_vesta
module Pasta_pallas = Marlin_plonk_bindings_pasta_pallas
module Tweedle_dee = Marlin_plonk_bindings_tweedle_dee
module Tweedle_dum = Marlin_plonk_bindings_tweedle_dum

(* URSs *)

module Pasta_fp_urs = Marlin_plonk_bindings_pasta_fp_urs
module Pasta_fq_urs = Marlin_plonk_bindings_pasta_fq_urs
module Tweedle_fp_urs = Marlin_plonk_bindings_tweedle_fp_urs
module Tweedle_fq_urs = Marlin_plonk_bindings_tweedle_fq_urs

(* Indices *)

module Pasta_fp_index = Marlin_plonk_bindings_pasta_fp_index
module Pasta_fq_index = Marlin_plonk_bindings_pasta_fq_index
module Tweedle_fp_index = Marlin_plonk_bindings_tweedle_fp_index
module Tweedle_fq_index = Marlin_plonk_bindings_tweedle_fq_index

(* Verification indices *)

module Pasta_fp_verifier_index = Marlin_plonk_bindings_pasta_fp_verifier_index
module Pasta_fq_verifier_index = Marlin_plonk_bindings_pasta_fq_verifier_index
module Tweedle_fp_verifier_index =
  Marlin_plonk_bindings_tweedle_fp_verifier_index
module Tweedle_fq_verifier_index =
  Marlin_plonk_bindings_tweedle_fq_verifier_index

(* Proofs *)
module Pasta_fp_proof = Marlin_plonk_bindings_pasta_fp_proof
module Pasta_fq_proof = Marlin_plonk_bindings_pasta_fq_proof
module Tweedle_fp_proof = Marlin_plonk_bindings_tweedle_fp_proof
module Tweedle_fq_proof = Marlin_plonk_bindings_tweedle_fq_proof

(* Oracles *)
module Pasta_fp_oracles = Marlin_plonk_bindings_pasta_fp_oracles
module Pasta_fq_oracles = Marlin_plonk_bindings_pasta_fq_oracles
module Tweedle_fp_oracles = Marlin_plonk_bindings_tweedle_fp_oracles
module Tweedle_fq_oracles = Marlin_plonk_bindings_tweedle_fq_oracles
