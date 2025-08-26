module Curve = Curve
module Poly_comm = Poly_comm

module Plonk_constraint_system : sig
  module Make = Kimchi_pasta_snarky_backend.Plonk_constraint_system.Make

  module Plonk_constraint =
    Kimchi_pasta_snarky_backend.Plonk_constraint_system.Plonk_constraint

  type ('f, 'rust_gates) t =
    ('f, 'rust_gates) Kimchi_pasta_snarky_backend.Plonk_constraint_system.t

  val get_public_input_size : ('a, 'b) t -> int Core_kernel.Set_once.t

  (** Return the size of all the fixed lookup tables concatenated, without the
      built-in XOR and RangeCheck tables *)
  val get_concatenated_fixed_lookup_table_size : ('a, 'b) t -> int

  (** Return the size of all the runtime lookup tables concatenated *)
  val get_concatenated_runtime_lookup_table_size : ('a, 'b) t -> int

  (** Finalize the fixed lookup tables. The function can not be called twice *)
  val finalize_fixed_lookup_tables : _ t -> unit

  (** Finalize the runtime lookup table configurations. The function can not be
      called twice. *)
  val finalize_runtime_lookup_tables : _ t -> unit

  val get_rows_len : ('a, 'b) t -> int
end

module Dlog_plonk_based_keypair = Dlog_plonk_based_keypair
module Constants = Kimchi_pasta_snarky_backend.Constants
module Plonk_dlog_proof = Plonk_dlog_proof
module Plonk_dlog_oracles = Plonk_dlog_oracles

module Scalar_challenge : sig
  module Stable = Scalar_challenge.Stable

  type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }
  [@@deriving yojson, sexp, compare, equal, hash]

  val create : 'a -> 'a t

  module Make_typ (Impl : Snarky_backendless.Snark_intf.Run) : sig
    val typ : ('a, 'b) Impl.Typ.t -> ('a t, 'b t) Impl.Typ.t
  end

  val typ :
       ('a, 'b) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
    -> ('a t, 'b t) Kimchi_pasta_snarky_backend.Step_impl.Typ.t

  val wrap_typ :
       ('a, 'b) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
    -> ('a t, 'b t) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t

  val map : 'a t -> f:('a -> 'b) -> 'b t
end

module Endoscale_round = Kimchi_pasta_snarky_backend.Endoscale_round
module Scale_round = Kimchi_pasta_snarky_backend.Scale_round
module Endoscale_scalar_round =
  Kimchi_pasta_snarky_backend.Endoscale_scalar_round
module Intf = Kimchi_pasta_snarky_backend.Intf
module Plonk_types = Plonk_types
module Plonk_verification_key_evals = Plonk_verification_key_evals
