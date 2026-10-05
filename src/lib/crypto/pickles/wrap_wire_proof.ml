open Core_kernel
open Pickles_types
module Columns = Nat.N15
module Columns_vec = Vector.Vector_15
module Coefficients = Nat.N15
module Coefficients_vec = Vector.Vector_15
module Quotient_polynomial = Nat.N7
module Quotient_polynomial_vec = Vector.Vector_7
module Permuts_minus_1 = Nat.N6
module Permuts_minus_1_vec = Vector.Vector_6

[@@@warning "-4"]

module Commitments = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
            Mina_wire_types.Pickles.Concrete_.Wrap_wire_proof.Commitments.V1.t =
        { w_comm :
            (Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t)
            Columns_vec.Stable.V1.t
        ; z_comm :
            Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t
        ; t_comm :
            (Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t)
            Quotient_polynomial_vec.Stable.V1.t
        }
      [@@deriving compare, sexp, yojson, hash, equal]

      [@@@warning "+4"]

      let to_latest = Fn.id
    end
  end]

  let to_kimchi ({ w_comm; z_comm; t_comm } : t) :
      Backend.Tock.Curve.Affine.t Plonk_types.Messages.t =
    { w_comm = Vector.map ~f:(fun x -> [| x |]) w_comm
    ; z_comm = [| z_comm |]
    ; t_comm = Array.map ~f:(fun x -> x) (Vector.to_array t_comm)
    ; lookup = None
    }

  let of_kimchi
      ({ w_comm; z_comm; t_comm; lookup = _ } :
        Backend.Tock.Curve.Affine.t Plonk_types.Messages.t ) : t =
    { w_comm = Vector.map ~f:(fun x -> x.(0)) w_comm
    ; z_comm = z_comm.(0)
    ; t_comm = Vector.of_array_and_length_exn t_comm Quotient_polynomial.n
    }
end

[@@@warning "-4"]

module Evaluations = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
            Mina_wire_types.Pickles.Concrete_.Wrap_wire_proof.Evaluations.V1.t =
        { w :
            (Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t)
            Columns_vec.Stable.V1.t
        ; coefficients :
            (Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t)
            Columns_vec.Stable.V1.t
        ; z : Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; s :
            (Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t)
            Permuts_minus_1_vec.Stable.V1.t
        ; generic_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; poseidon_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; complete_add_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; mul_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; emul_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        ; endomul_scalar_selector :
            Backend.Tock.Field.Stable.V1.t * Backend.Tock.Field.Stable.V1.t
        }
      [@@deriving compare, sexp, yojson, hash, equal]

      [@@@warning "+4"]

      let to_latest = Fn.id
    end
  end]

  let to_kimchi
      ({ w
       ; coefficients
       ; z
       ; s
       ; generic_selector
       ; poseidon_selector
       ; complete_add_selector
       ; mul_selector
       ; emul_selector
       ; endomul_scalar_selector
       } :
        t ) :
      (Backend.Tock.Field.t array * Backend.Tock.Field.t array)
      Plonk_types.Evals.t =
    let conv (x, y) = ([| x |], [| y |]) in
    { w = Vector.map ~f:conv w
    ; coefficients = Vector.map ~f:conv coefficients
    ; z = conv z
    ; s = Vector.map ~f:conv s
    ; generic_selector = conv generic_selector
    ; poseidon_selector = conv poseidon_selector
    ; complete_add_selector = conv complete_add_selector
    ; mul_selector = conv mul_selector
    ; emul_selector = conv emul_selector
    ; endomul_scalar_selector = conv endomul_scalar_selector
    ; range_check0_selector = None
    ; range_check1_selector = None
    ; foreign_field_add_selector = None
    ; foreign_field_mul_selector = None
    ; xor_selector = None
    ; rot_selector = None
    ; lookup_aggregation = None
    ; lookup_table = None
    ; lookup_sorted = [ None; None; None; None; None ]
    ; runtime_lookup_table = None
    ; runtime_lookup_table_selector = None
    ; xor_lookup_selector = None
    ; lookup_gate_lookup_selector = None
    ; range_check_lookup_selector = None
    ; foreign_field_mul_lookup_selector = None
    }

  let of_kimchi
      ({ w
       ; coefficients
       ; z
       ; s
       ; generic_selector
       ; poseidon_selector
       ; complete_add_selector
       ; mul_selector
       ; emul_selector
       ; endomul_scalar_selector
       ; range_check0_selector = _
       ; range_check1_selector = _
       ; foreign_field_add_selector = _
       ; foreign_field_mul_selector = _
       ; xor_selector = _
       ; rot_selector = _
       ; lookup_aggregation = _
       ; lookup_table = _
       ; lookup_sorted = _
       ; runtime_lookup_table = _
       ; runtime_lookup_table_selector = _
       ; xor_lookup_selector = _
       ; lookup_gate_lookup_selector = _
       ; range_check_lookup_selector = _
       ; foreign_field_mul_lookup_selector = _
       } :
        (Backend.Tock.Field.t array * Backend.Tock.Field.t array)
        Plonk_types.Evals.t ) : t =
    let conv (x, y) = (x.(0), y.(0)) in
    { w = Vector.map ~f:conv w
    ; coefficients = Vector.map ~f:conv coefficients
    ; z = conv z
    ; s = Vector.map ~f:conv s
    ; generic_selector = conv generic_selector
    ; poseidon_selector = conv poseidon_selector
    ; complete_add_selector = conv complete_add_selector
    ; mul_selector = conv mul_selector
    ; emul_selector = conv emul_selector
    ; endomul_scalar_selector = conv endomul_scalar_selector
    }
end

[@@@warning "-4"]

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Mina_wire_types.Pickles.Concrete_.Wrap_wire_proof.V1.t =
      { commitments : Commitments.Stable.V1.t
      ; evaluations : Evaluations.Stable.V1.t
      ; ft_eval1 : Backend.Tock.Field.Stable.V1.t
      ; bulletproof :
          ( Backend.Tick.Field.Stable.V1.t * Backend.Tick.Field.Stable.V1.t
          , Backend.Tock.Field.Stable.V1.t )
          Plonk_types.Openings.Bulletproof.Stable.V1.t
            (* TODO-URGENT: Validate bulletproof length on the rust side *)
      }
    [@@deriving compare, sexp, yojson, hash, equal]

    [@@@warning "+4"]

    let to_latest = Fn.id
  end
end]

let to_kimchi_proof ({ commitments; bulletproof; evaluations; ft_eval1 } : t) :
    Backend.Tock.Proof.t =
  { messages = Commitments.to_kimchi commitments
  ; openings =
      { proof = bulletproof
      ; evals = Evaluations.to_kimchi evaluations
      ; ft_eval1
      }
  }

let of_kimchi_proof
    ({ messages; openings = { proof; evals; ft_eval1 } } : Backend.Tock.Proof.t)
    : t =
  { commitments = Commitments.of_kimchi messages
  ; bulletproof = proof
  ; evaluations = Evaluations.of_kimchi evals
  ; ft_eval1
  }
