(* This file is generated automatically with ocaml_gen. *)
(** The constraints exposed by Kimchi. *)

module Constraints = struct
  (** The legacy R1CS constraints. *)
  type nonrec 'var r1cs =
    | Boolean of 'var
    | Equal of 'var * 'var
    | Square of 'var * 'var
    | R1CS of 'var * 'var * 'var
        (** The inputs to the different custom gates. *)

  module Inputs = struct
    type nonrec ('var, 'field) generic =
      { l : 'field * 'var
      ; r : 'field * 'var
      ; o : 'field * 'var
      ; m : 'field
      ; c : 'field
      }

    type nonrec 'var poseidon_input =
      { states : 'var array array; last : 'var array }

    type nonrec 'var ec_add =
      { p1 : 'var * 'var
      ; p2 : 'var * 'var
      ; p3 : 'var * 'var
      ; inf : 'var
      ; same_x : 'var
      ; slope : 'var
      ; inf_z : 'var
      ; x21_inv : 'var
      }

    type nonrec 'a ec_endoscale_round =
      { xt : 'a
      ; yt : 'a
      ; xp : 'a
      ; yp : 'a
      ; n_acc : 'a
      ; xr : 'a
      ; yr : 'a
      ; s1 : 'a
      ; s3 : 'a
      ; b1 : 'a
      ; b2 : 'a
      ; b3 : 'a
      ; b4 : 'a
      }

    type nonrec 'a ec_scale_round =
      { accs : ('a * 'a) array
      ; bits : 'a array
      ; ss : 'a array
      ; base : 'a * 'a
      ; n_prev : 'a
      ; n_next : 'a
      }

    type nonrec 'var ec_endoscale =
      { state : 'var ec_endoscale_round array
      ; xs : 'var
      ; ys : 'var
      ; n_acc : 'var
      }

    type nonrec 'a ec_endoscale_scalar_round =
      { n0 : 'a
      ; n8 : 'a
      ; a0 : 'a
      ; b0 : 'a
      ; a8 : 'a
      ; b8 : 'a
      ; x0 : 'a
      ; x1 : 'a
      ; x2 : 'a
      ; x3 : 'a
      ; x4 : 'a
      ; x5 : 'a
      ; x6 : 'a
      ; x7 : 'a
      }
  end

  (** The custom gates exposed by Kimchi. *)
  type nonrec ('var, 'field) kimchi =
    | Basic of ('var, 'field) Inputs.generic
    | Poseidon of 'var array array
    | Poseidon2 of 'var Inputs.poseidon_input
    | EcAddComplete of 'var Inputs.ec_add
    | EcScale of 'var Inputs.ec_scale_round array
    | EcEndoscale of 'var Inputs.ec_endoscale
    | EcEndoscalar of 'var Inputs.ec_endoscale_scalar_round array
end

module Fp = struct
  module Cvar = struct
    type nonrec t

    external of_index_unsafe : int -> t = "fp_var_of_index_unsafe"

    external constant : Pasta_bindings.Fp.t -> t = "fp_var_constant"

    external add : t -> t -> t = "fp_var_add"

    external negate : t -> t = "fp_var_negate"

    external scale : t -> Pasta_bindings.Fp.t -> t = "fp_var_scale"

    external sub : t -> t -> t = "fp_var_sub"

    external to_constant : t -> Pasta_bindings.Fp.t option
      = "fp_var_to_constant"
  end

  module Constraint_system = struct
    type nonrec t

    external create : unit -> t = "fp_cs_create"

    external add_legacy_constraint : t -> Cvar.t Constraints.r1cs -> unit
      = "fp_cs_add_legacy_constraint"

    external add_kimchi_constraint :
      t -> (Cvar.t, Pasta_bindings.Fp.t) Constraints.kimchi -> unit
      = "fp_cs_add_kimchi_constraint"

    external finalize : t -> unit = "fp_cs_finalize"

    external digest : t -> bytes = "fp_cs_digest"

    external get_rows_len : t -> int = "fp_cs_get_rows_len"

    external set_primary_input_size : t -> int -> unit
      = "fp_cs_set_primary_input_size"

    external get_primary_input_size : t -> int = "fp_cs_get_primary_input_size"

    external get_prev_challenges : t -> int option = "fp_cs_get_prev_challenges"

    external set_prev_challenges : t -> int -> unit
      = "fp_cs_set_prev_challenges"

    external finalize_and_get_gates :
      t -> Kimchi_bindings.Protocol.Gates.Vector.Fp.t
      = "fp_cs_finalize_and_get_gates"

    external compute_witness :
         t
      -> Kimchi_bindings.FieldVectors.Fp.t
      -> Kimchi_bindings.FieldVectors.Fp.t
      -> Kimchi_bindings.FieldVectors.Fp.t array = "fp_cs_compute_witness"

    external to_json : t -> string = "fp_cs_to_json"
  end

  module State = struct
    type nonrec t

    external make : int -> bool -> bool -> t = "fp_state_make"

    external debug : t -> string = "fp_state_debug"

    external add_legacy_constraint : t -> Cvar.t Constraints.r1cs -> unit
      = "fp_state_add_legacy_constraint"

    external add_kimchi_constraint :
      t -> (Cvar.t, Pasta_bindings.Fp.t) Constraints.kimchi -> unit
      = "fp_state_add_kimchi_constraint"

    external evaluate_var : t -> Cvar.t -> Pasta_bindings.Fp.t
      = "fp_state_evaluate_var"

    external store_field_elt : t -> Pasta_bindings.Fp.t -> Cvar.t
      = "fp_state_store_field_elt"

    external alloc_var : t -> Cvar.t = "fp_state_alloc_var"

    external has_witness : t -> bool = "fp_state_has_witness"

    external as_prover : t -> bool = "fp_state_as_prover"

    external set_as_prover : t -> bool -> unit = "fp_state_set_as_prover"

    external eval_constraints : t -> bool = "fp_state_eval_constraints"

    external next_auxiliary : t -> int = "fp_state_next_auxiliary"

    external system : t -> Constraint_system.t option = "fp_state_system"

    external finalize : t -> unit = "fp_state_finalize"

    external set_public_inputs : t -> Kimchi_bindings.FieldVectors.Fp.t -> unit
      = "fp_state_set_public_inputs"

    external get_private_inputs : t -> Kimchi_bindings.FieldVectors.Fp.t
      = "fp_state_get_private_inputs"

    external seal : t -> Cvar.t -> Cvar.t = "fp_state_seal"
  end
end

module Fq = struct
  module Cvar = struct
    type nonrec t

    external of_index_unsafe : int -> t = "fq_var_of_index_unsafe"

    external constant : Pasta_bindings.Fq.t -> t = "fq_var_constant"

    external add : t -> t -> t = "fq_var_add"

    external negate : t -> t = "fq_var_negate"

    external scale : t -> Pasta_bindings.Fq.t -> t = "fq_var_scale"

    external sub : t -> t -> t = "fq_var_sub"

    external to_constant : t -> Pasta_bindings.Fq.t option
      = "fq_var_to_constant"
  end

  module Constraint_system = struct
    type nonrec t

    external create : unit -> t = "fq_cs_create"

    external add_legacy_constraint : t -> Cvar.t Constraints.r1cs -> unit
      = "fq_cs_add_legacy_constraint"

    external add_kimchi_constraint :
      t -> (Cvar.t, Pasta_bindings.Fq.t) Constraints.kimchi -> unit
      = "fq_cs_add_kimchi_constraint"

    external finalize : t -> unit = "fq_cs_finalize"

    external digest : t -> bytes = "fq_cs_digest"

    external get_rows_len : t -> int = "fq_cs_get_rows_len"

    external set_primary_input_size : t -> int -> unit
      = "fq_cs_set_primary_input_size"

    external get_primary_input_size : t -> int = "fq_cs_get_primary_input_size"

    external get_prev_challenges : t -> int option = "fq_cs_get_prev_challenges"

    external set_prev_challenges : t -> int -> unit
      = "fq_cs_set_prev_challenges"

    external finalize_and_get_gates :
      t -> Kimchi_bindings.Protocol.Gates.Vector.Fq.t
      = "fq_cs_finalize_and_get_gates"

    external compute_witness :
         t
      -> Kimchi_bindings.FieldVectors.Fq.t
      -> Kimchi_bindings.FieldVectors.Fq.t
      -> Kimchi_bindings.FieldVectors.Fq.t array = "fq_cs_compute_witness"

    external to_json : t -> string = "fq_cs_to_json"
  end

  module State = struct
    type nonrec t

    external make : int -> bool -> bool -> t = "fq_state_make"

    external debug : t -> string = "fq_state_debug"

    external add_legacy_constraint : t -> Cvar.t Constraints.r1cs -> unit
      = "fq_state_add_legacy_constraint"

    external add_kimchi_constraint :
      t -> (Cvar.t, Pasta_bindings.Fq.t) Constraints.kimchi -> unit
      = "fq_state_add_kimchi_constraint"

    external evaluate_var : t -> Cvar.t -> Pasta_bindings.Fq.t
      = "fq_state_evaluate_var"

    external store_field_elt : t -> Pasta_bindings.Fq.t -> Cvar.t
      = "fq_state_store_field_elt"

    external alloc_var : t -> Cvar.t = "fq_state_alloc_var"

    external has_witness : t -> bool = "fq_state_has_witness"

    external as_prover : t -> bool = "fq_state_as_prover"

    external set_as_prover : t -> bool -> unit = "fq_state_set_as_prover"

    external eval_constraints : t -> bool = "fq_state_eval_constraints"

    external next_auxiliary : t -> int = "fq_state_next_auxiliary"

    external system : t -> Constraint_system.t option = "fq_state_system"

    external finalize : t -> unit = "fq_state_finalize"

    external set_public_inputs : t -> Kimchi_bindings.FieldVectors.Fq.t -> unit
      = "fq_state_set_public_inputs"

    external get_private_inputs : t -> Kimchi_bindings.FieldVectors.Fq.t
      = "fq_state_get_private_inputs"

    external seal : t -> Cvar.t -> Cvar.t = "fq_state_seal"
  end
end
