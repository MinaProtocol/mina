(** Interface definitions for the Kimchi backend constraint system.

    This module defines the interfaces for working with the Kimchi constraint system
    over the Pasta curves (Pallas and Vesta). It provides functionality for
    building, managing, and finalizing constraint systems. *)

open Core_kernel

(** Basic accessors for constraint system properties.

    This module type defines the fundamental operations for creating and
    accessing properties of a constraint system, including input sizes,
    row counts, and challenge parameters. *)
module type With_accessors = sig
  (** The constraint system type. *)
  type t

  (** Create a new empty constraint system. *)
  val create : unit -> t

  (** Get the public input size (can only be set once). *)
  val get_public_input_size : t -> int Set_once.t

  (** Get the number of primary (public) inputs. *)
  val get_primary_input_size : t -> int

  (** Set the number of primary (public) inputs. *)
  val set_primary_input_size : t -> int -> unit

  (** Get the number of auxiliary (private witness) inputs. *)
  val get_auxiliary_input_size : t -> int

  (** Set the number of auxiliary (private witness) inputs. *)
  val set_auxiliary_input_size : t -> int -> unit

  (** Get the number of previous challenges used in recursive proofs.
      Returns [None] if not set. *)
  val get_prev_challenges : t -> int option

  (** Set the number of previous challenges for recursive proofs. *)
  val set_prev_challenges : t -> int -> unit

  (** Get the total number of rows in the constraint system. *)
  val get_rows_len : t -> int

  (** Get the total number of constraints added to the system. *)
  val num_constraints : t -> int

  (** Get the index of the next available row for adding constraints. *)
  val next_row : t -> int
end

(** Complete constraint system interface with all operations.

    This module type extends [With_accessors] with constraint management,
    witness computation, lookup tables, and finalization operations. *)
module type Full = sig
  (** Field element type (either Pallas or Vesta scalar field). *)
  type fp

  (** Variable type representing field elements in constraints. *)
  type field_var

  (** Gate collection type for the compiled constraint system. *)
  type gates

  (** Constraint types and operations.

      This module provides different types of constraints that can be added
      to the constraint system, along with evaluation and debugging functions. *)
  module Constraint : sig
    (** A basic Plonk constraint over field variables and field elements. *)
    type t =
      ( field_var
      , fp )
      Kimchi_pasta_snarky_backend.Plonk_constraint_system.Plonk_constraint.basic
    [@@deriving sexp]

    (** Create a boolean constraint: x * (x - 1) = 0.
        Ensures the variable is either 0 or 1. *)
    val boolean : field_var -> t

    (** Create an equality constraint: x = y. *)
    val equal : field_var -> field_var -> t

    (** Create an R1CS constraint: a * b = c.
        This is the fundamental constraint type in R1CS systems. *)
    val r1cs : field_var -> field_var -> field_var -> t

    (** Create a square constraint: x * x = y. *)
    val square : field_var -> field_var -> t

    (** Evaluate a constraint given a variable assignment.
        Returns [true] if the constraint is satisfied. *)
    val eval : t -> (field_var -> fp) -> bool

    (** Generate a human-readable string representation of the constraint
        with the given variable assignment for debugging. *)
    val log_constraint : t -> (field_var -> fp) -> string
  end

  (** Alias for constraint type. *)
  type constraint_ = Constraint.t

  include
    With_accessors
      with type t = (fp, gates) Kimchi_backend_common.Plonk_constraint_system.t

  (** Add a constraint to the constraint system. *)
  val add_constraint : t -> Constraint.t -> unit

  (** Compute the witness for the constraint system.

      In this context, "witness" refers to the entire execution trace,
      including both public inputs and private values.

      @param t The constraint system
      @param int -> fp Function mapping variable indices to field values
      @return A pair of:
        - The witness (full trace) columns as a 2D array
        - Runtime lookup tables *)
  val compute_witness :
    t -> (int -> fp) -> fp array array * fp Kimchi_types.runtime_table array

  (** Finalize the constraint system, preparing it for proof generation.
      This must be called before generating proofs. *)
  val finalize : t -> unit

  (** Finalize the constraint system and extract the gates and lookup tables.

      @return A triple of:
        - Compiled gates
        - Fixed lookup tables
        - Runtime lookup table configurations *)
  val finalize_and_get_gates :
       t
    -> gates
       * fp Kimchi_types.lookup_table array
       * fp Kimchi_types.runtime_table_cfg array

  (** Return the size of all the fixed lookup tables concatenated, without the
      built-in XOR and RangeCheck tables. *)
  val get_concatenated_fixed_lookup_table_size : t -> int

  (** Return the size of all the runtime lookup tables concatenated. *)
  val get_concatenated_runtime_lookup_table_size : t -> int

  (** Finalize the fixed lookup tables. The function can not be called twice. *)
  val finalize_fixed_lookup_tables : t -> unit

  (** Finalize the runtime lookup table configurations. The function can not be
      called twice. *)
  val finalize_runtime_lookup_tables : t -> unit

  (** Compute an MD5 digest of the constraint system.
      Useful for caching and verification of constraint system integrity. *)
  val digest : t -> Md5.t

  (** Serialize the constraint system to JSON format.
      Useful for debugging and external analysis. *)
  val to_json : t -> string
end
