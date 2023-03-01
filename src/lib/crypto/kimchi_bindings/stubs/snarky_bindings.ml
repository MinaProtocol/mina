(* This file is generated automatically with ocaml_gen. *)

module Fp = struct
  module Cvar = struct
    type nonrec t
  end

  module Constraint_system = struct
    type nonrec t

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
  end

  module Constraint_system = struct
    type nonrec t

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
