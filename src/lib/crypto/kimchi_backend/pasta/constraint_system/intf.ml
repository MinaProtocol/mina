open Core_kernel

module type With_accessors = sig
  type t

  val create : unit -> t

  val get_public_input_size : t -> int Set_once.t

  val get_primary_input_size : t -> int

  val set_primary_input_size : t -> int -> unit

  val get_auxiliary_input_size : t -> int

  val set_auxiliary_input_size : t -> int -> unit

  val get_prev_challenges : t -> int option

  val set_prev_challenges : t -> int -> unit

  val get_rows_len : t -> int

  val num_constraints : t -> int

  val next_row : t -> int
end

module type Full = sig
  type fp

  type field_var

  type gates

  module Constraint : sig
    type t =
      ( field_var
      , fp )
      Kimchi_pasta_snarky_backend.Plonk_constraint_system.Plonk_constraint.basic
    [@@deriving sexp]

    val boolean : field_var -> t

    val equal : field_var -> field_var -> t

    val r1cs : field_var -> field_var -> field_var -> t

    val square : field_var -> field_var -> t

    val eval : t -> (field_var -> fp) -> bool

    val log_constraint : t -> (field_var -> fp) -> string
  end

  type constraint_ = Constraint.t

  include
    With_accessors
      with type t = (fp, gates) Kimchi_backend_common.Plonk_constraint_system.t

  val add_constraint : t -> Constraint.t -> unit

  val compute_witness :
    t -> (int -> fp) -> fp array array * fp Kimchi_types.runtime_table array

  val finalize : t -> unit

  val finalize_and_get_gates :
       t
    -> gates
       * fp Kimchi_types.lookup_table array
       * fp Kimchi_types.runtime_table_cfg array

  (** Return the size of all the fixed lookup tables concatenated, without the
      built-in XOR and RangeCheck tables *)
  val get_concatenated_fixed_lookup_table_size : t -> int

  (** Return the size of all the runtime lookup tables concatenated *)
  val get_concatenated_runtime_lookup_table_size : t -> int

  (** Finalize the fixed lookup tables. The function can not be called twice *)
  val finalize_fixed_lookup_tables : t -> unit

  (** Finalize the runtime lookup table configurations. The function can not be called twice. *)
  val finalize_runtime_lookup_tables : t -> unit

  val digest : t -> Md5.t

  val to_json : t -> string
end
