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

  type gates

  include
    With_accessors
      with type t = (fp, gates) Kimchi_backend_common.Plonk_constraint_system.t

  val add_constraint :
       ?label:string
    -> t
    -> (fp Snarky_backendless.Cvar.t, fp) Snarky_backendless.Constraint.basic
    -> unit

  val compute_witness : t -> (int -> fp) -> fp array array

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

  val digest : t -> Md5.t

  val to_json : t -> string
end
