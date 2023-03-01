(* This file is generated automatically with ocaml_gen. *)

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

    external add_constraint : string option -> t -> int -> unit
      = "fp_cs_add_constraint"

    external finalize : t -> unit = "fp_cs_finalize"

    external digest : t -> bytes = "fp_cs_digest"

    external get_rows_len : t -> int = "fp_cs_get_rows_len"

    external set_auxiliary_input_size : t -> int -> unit
      = "fp_cs_set_auxiliary_input_size"

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
  end

  module State = struct
    type nonrec t
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

    external add_constraint : string option -> t -> int -> unit
      = "fq_cs_add_constraint"

    external finalize : t -> unit = "fq_cs_finalize"

    external digest : t -> bytes = "fq_cs_digest"

    external get_rows_len : t -> int = "fq_cs_get_rows_len"

    external set_auxiliary_input_size : t -> int -> unit
      = "fq_cs_set_auxiliary_input_size"

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
  end

  module State = struct
    type nonrec t
  end
end
