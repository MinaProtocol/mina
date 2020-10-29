module Types = Marlin_plonk_bindings_types

(** Biginteger types *)

module Bigint_256 = Marlin_plonk_bindings_bigint_256
module Bigint_384 = Marlin_plonk_bindings_bigint_384

(** Finite fields *)

module Tweedle_fp = Marlin_plonk_bindings_tweedle_fp
module Tweedle_fq = Marlin_plonk_bindings_tweedle_fq
module Bn_382_fp = Marlin_plonk_bindings_bn_382_fp
module Bn_382_fq = Marlin_plonk_bindings_bn_382_fq

(* Finite field vectors *)

module Tweedle_fp_vector = Marlin_plonk_bindings_tweedle_fp_vector
module Tweedle_fq_vector = Marlin_plonk_bindings_tweedle_fq_vector
module Bn_382_fp_vector = Marlin_plonk_bindings_bn_382_fp_vector
module Bn_382_fq_vector = Marlin_plonk_bindings_bn_382_fq_vector

(* Groups *)

module Tweedle_dee = Marlin_plonk_bindings_tweedle_dee
module Tweedle_dum = Marlin_plonk_bindings_tweedle_dum

(* URSs *)

module Tweedle_fp_urs = Marlin_plonk_bindings_tweedle_fp_urs
module Tweedle_fq_urs = Marlin_plonk_bindings_tweedle_fq_urs

(* Indices *)

module Tweedle_fp_index = Marlin_plonk_bindings_tweedle_fp_index
module Tweedle_fq_index = Marlin_plonk_bindings_tweedle_fq_index

(* Verification indices *)

module Tweedle_fp_verifier_index =
  Marlin_plonk_bindings_tweedle_fp_verifier_index
module Tweedle_fq_verifier_index =
  Marlin_plonk_bindings_tweedle_fq_verifier_index
