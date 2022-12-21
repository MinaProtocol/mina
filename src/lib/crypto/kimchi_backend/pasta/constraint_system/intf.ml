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

  val next_row : t -> int
end

module type Full = sig
  include With_accessors

  type fp

  type gates

  val add_constraint :
       ?label:string
    -> t
    -> (fp Snarky_backendless.Cvar.t, fp) Snarky_backendless.Constraint.basic
    -> unit

  val compute_witness : t -> (int -> fp) -> fp array array

  val finalize : t -> unit

  val finalize_and_get_gates : t -> gates

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
