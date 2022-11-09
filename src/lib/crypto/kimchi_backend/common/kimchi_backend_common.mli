module Bigint = Bigint
module Field = Field
module Curve = Curve
module Poly_comm = Poly_comm

module Plonk_constraint_system : sig
  module Make = Plonk_constraint_system.Make
  module Plonk_constraint = Plonk_constraint_system.Plonk_constraint

  type ('f, 'rust_gates) t

  val get_public_input_size : ('a, 'b) t -> int Core_kernel.Set_once.t

  val get_rows_len : ('a, 'b) t -> int
end

module Dlog_plonk_based_keypair = Dlog_plonk_based_keypair
module Constants = Constants
module Plonk_dlog_proof = Plonk_dlog_proof
module Plonk_dlog_oracles = Plonk_dlog_oracles

module Scalar_challenge : sig
  module Stable = Scalar_challenge.Stable

  type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }

  val to_yojson : ('f -> Yojson.Safe.t) -> 'f t -> Yojson.Safe.t

  val of_yojson :
       (Yojson.Safe.t -> 'f Ppx_deriving_yojson_runtime.error_or)
    -> Yojson.Safe.t
    -> 'f t Ppx_deriving_yojson_runtime.error_or

  val t_of_sexp :
    (Ppx_sexp_conv_lib.Sexp.t -> 'f) -> Ppx_sexp_conv_lib.Sexp.t -> 'f t

  val sexp_of_t :
    ('f -> Ppx_sexp_conv_lib.Sexp.t) -> 'f t -> Ppx_sexp_conv_lib.Sexp.t

  val compare : ('f -> 'f -> int) -> 'f t -> 'f t -> int

  val equal : ('f -> 'f -> bool) -> 'f t -> 'f t -> bool

  val hash_fold_t :
       (Base_internalhash_types.state -> 'f -> Base_internalhash_types.state)
    -> Base_internalhash_types.state
    -> 'f t
    -> Base_internalhash_types.state

  val create : 'a -> 'a t

  val typ :
       ('a, 'b, 'c) Snarky_backendless.Typ.t
    -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module Endoscale_round = Endoscale_round
module Scale_round = Scale_round
module Endoscale_scalar_round = Endoscale_scalar_round
module Intf = Intf
