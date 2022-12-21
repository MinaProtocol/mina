(* this is going to replace plonk_constraint_system *)

(** A gate interface, parameterized by a field. *)
module type Gate_vector_intf = sig
  open Unsigned.Size_t.Unsigned

  type field

  type t

  val create : unit -> t

  val add : t -> field Kimchi_types.circuit_gate -> unit

  val get : t -> int -> field Kimchi_types.circuit_gate

  val digest : int -> t -> bytes
end

(** The interface of snarky's constraint system. *)
module type Constraint_system_intf = sig
  open Core_kernel

  type field

  module Gate_vector : Gate_vector_intf

  type t

  (** a cvar is a representation of a frontend var. Most likely usize? *)
  type cvar

  val create : unit -> t

  val get_public_input_size : t -> int Set_once.t

  val get_primary_input_size : t -> int

  val set_primary_input_size : t -> int -> unit

  val get_auxiliary_input_size : t -> int

  val set_auxiliary_input_size : t -> int -> unit

  val get_prev_challenges : t -> int option

  val set_prev_challenges : t -> int -> unit

  val get_rows_len : t -> int

  val next_row : t -> int

  val add_constraint :
       ?label:string
    -> t
    -> ( Fp.t Snarky_backendless.Cvar.t
       , Fp.t )
       Snarky_backendless.Constraint.basic
    -> unit

  val compute_witness : t -> (int -> Fp.t) -> Fp.t array array

  val finalize : t -> unit

  val finalize_and_get_gates : t -> Gates.t

  val digest : t -> Md5.t

  val to_json :
       t
    -> ([ `Null
        | `Bool of bool
        | `Int of int
        | `Intlit of string
        | `Float of float
        | `String of string
        | `Assoc of (string * 'json) list
        | `List of 'json list
        | `Tuple of 'json list
        | `Variant of string * 'json option ]
        as
        'json )
end
