open Core_kernel
open Pickles_types
open Import
open Kimchi_pasta.Pasta

module Verifier_index_json = struct
  module Lookup = struct
    type 't lookup_selectors =
          't Kimchi_types.VerifierIndex.Lookup.lookup_selectors =
      { lookup : 't option
      ; xor : 't option
      ; range_check : 't option
      ; ffmul : 't option
      }
    [@@deriving yojson]

    type lookup_pattern = Kimchi_types.lookup_pattern =
      | Xor
      | Lookup
      | RangeCheck
      | ForeignFieldMul
    [@@deriving yojson]

    type lookup_patterns = Kimchi_types.lookup_patterns =
      { xor : bool
      ; lookup : bool
      ; range_check : bool
      ; foreign_field_mul : bool
      }
    [@@deriving yojson]

    type lookup_features = Kimchi_types.lookup_features =
      { patterns : lookup_patterns
      ; joint_lookup_used : bool
      ; uses_runtime_tables : bool
      }
    [@@deriving yojson]

    type lookup_info = Kimchi_types.VerifierIndex.Lookup.lookup_info =
      { max_per_row : int; max_joint_size : int; features : lookup_features }
    [@@deriving yojson]

    type 'polyComm t = 'polyComm Kimchi_types.VerifierIndex.Lookup.t =
      { joint_lookup_used : bool
      ; lookup_table : 'polyComm array
      ; lookup_selectors : 'polyComm lookup_selectors
      ; table_ids : 'polyComm option
      ; lookup_info : lookup_info
      ; runtime_tables_selector : 'polyComm option
      }
    [@@deriving yojson]
  end

  type 'fr domain = 'fr Kimchi_types.VerifierIndex.domain =
    { log_size_of_group : int; group_gen : 'fr }
  [@@deriving yojson]

  type 'polyComm verification_evals =
        'polyComm Kimchi_types.VerifierIndex.verification_evals =
    { sigma_comm : 'polyComm array
    ; coefficients_comm : 'polyComm array
    ; generic_comm : 'polyComm
    ; psm_comm : 'polyComm
    ; complete_add_comm : 'polyComm
    ; mul_comm : 'polyComm
    ; emul_comm : 'polyComm
    ; endomul_scalar_comm : 'polyComm
    ; xor_comm : 'polyComm option
    ; range_check0_comm : 'polyComm option
    ; range_check1_comm : 'polyComm option
    ; foreign_field_add_comm : 'polyComm option
    ; foreign_field_mul_comm : 'polyComm option
    ; rot_comm : 'polyComm option
    }
  [@@deriving yojson]

  type ('fr, 'sRS, 'polyComm) verifier_index =
        ('fr, 'sRS, 'polyComm) Kimchi_types.VerifierIndex.verifier_index =
    { domain : 'fr domain
    ; max_poly_size : int
    ; public : int
    ; prev_challenges : int
    ; srs : 'sRS
    ; evals : 'polyComm verification_evals
    ; shifts : 'fr array
    ; lookup_index : 'polyComm Lookup.t option
    }
  [@@deriving yojson]

  type 'f or_infinity = 'f Kimchi_types.or_infinity =
    | Infinity
    | Finite of ('f * 'f)
  [@@deriving yojson]

  type 'g polycomm = 'g Kimchi_types.poly_comm =
    { unshifted : 'g array; shifted : 'g option }
  [@@deriving yojson]

  let to_yojson fp fq =
    verifier_index_to_yojson fp
      (fun _ -> `Null)
      (polycomm_to_yojson (or_infinity_to_yojson fq))
end

module Data = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { constraints : int } [@@deriving yojson]

      let to_latest = Fn.id
    end
  end]
end

module Repr = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { commitments :
            Backend.Tock.Curve.Affine.Stable.V1.t
            Plonk_verification_key_evals.Stable.V2.t
        ; data : Data.Stable.V1.t
        }
      [@@deriving to_yojson]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned_binable
module Stable = struct
  module V2 = struct
    type t =
      { commitments : Backend.Tock.Curve.Affine.t Plonk_verification_key_evals.t
      ; index :
          (Impls.Wrap.Verification_key.t
          [@to_yojson
            Verifier_index_json.to_yojson Backend.Tock.Field.to_yojson
              Backend.Tick.Field.to_yojson] )
      ; data : Data.t
      }
    [@@deriving fields, to_yojson]

    let to_latest = Fn.id

    let of_repr srs { Repr.commitments = c; data = d } =
      let t : Impls.Wrap.Verification_key.t =
        let log2_size = Int.ceil_log2 d.constraints in
        let public =
          let (T (input, conv, _conv_inv)) =
            Impls.Wrap.input
              ~feature_flags:
                (* TODO: Is this right? *) Plonk_types.Features.none ()
          in
          let (Typ typ) = input in
          typ.size_in_field_elements
        in
        { domain =
            { log_size_of_group = log2_size
            ; group_gen = Backend.Tock.Field.domain_generator ~log2_size
            }
        ; max_poly_size = 1 lsl Nat.to_int Rounds.Wrap.n
        ; public
        ; prev_challenges = 2 (* Due to Wrap_hack *)
        ; srs
        ; evals =
            (let g (x, y) =
               { Kimchi_types.unshifted = [| Kimchi_types.Finite (x, y) |]
               ; shifted = None
               }
             in
             { sigma_comm = Array.map ~f:g (Vector.to_array c.sigma_comm)
             ; coefficients_comm =
                 Array.map ~f:g (Vector.to_array c.coefficients_comm)
             ; generic_comm = g c.generic_comm
             ; mul_comm = g c.mul_comm
             ; psm_comm = g c.psm_comm
             ; emul_comm = g c.emul_comm
             ; complete_add_comm = g c.complete_add_comm
             ; endomul_scalar_comm = g c.endomul_scalar_comm
             ; xor_comm = None
             ; range_check0_comm = None
             ; range_check1_comm = None
             ; foreign_field_add_comm = None
             ; foreign_field_mul_comm = None
             ; rot_comm = None
             } )
        ; shifts = Common.tock_shifts ~log2_size
        ; lookup_index = None
        }
      in
      { commitments = c; data = d; index = t }

    include
      Binable.Of_binable
        (Repr.Stable.V2)
        (struct
          type nonrec t = t

          let to_binable { commitments; data; index = _ } =
            { Repr.commitments; data }

          let of_binable r = of_repr (Backend.Tock.Keypair.load_urs ()) r
        end)
  end
end]

let to_yojson = Stable.Latest.to_yojson

let dummy_commitments g =
  let open Plonk_types in
  { Plonk_verification_key_evals.sigma_comm =
      Vector.init Permuts.n ~f:(fun _ -> g)
  ; coefficients_comm = Vector.init Columns.n ~f:(fun _ -> g)
  ; generic_comm = g
  ; psm_comm = g
  ; complete_add_comm = g
  ; mul_comm = g
  ; emul_comm = g
  ; endomul_scalar_comm = g
  }

let dummy_step_commitments g =
  let open Plonk_types in
  { Plonk_verification_key_evals.Step.sigma_comm =
      Vector.init Permuts.n ~f:(fun _ -> g)
  ; coefficients_comm = Vector.init Columns.n ~f:(fun _ -> g)
  ; generic_comm = g
  ; psm_comm = g
  ; complete_add_comm = g
  ; mul_comm = g
  ; emul_comm = g
  ; endomul_scalar_comm = g
  ; xor_comm = None
  ; range_check0_comm = None
  ; range_check1_comm = None
  ; foreign_field_add_comm = None
  ; foreign_field_mul_comm = None
  ; rot_comm = None
  ; lookup_table_comm = Vector.init Lookup_sorted_minus_1.n ~f:(fun _ -> None)
  ; lookup_table_ids = None
  ; runtime_tables_selector = None
  ; lookup_selector_lookup = None
  ; lookup_selector_xor = None
  ; lookup_selector_range_check = None
  ; lookup_selector_ffmul = None
  }

let dummy =
  lazy
    (let rows = Domain.size (Common.wrap_domains ~proofs_verified:2).h in
     let g = Backend.Tock.Curve.(to_affine_exn one) in
     { Repr.commitments = dummy_commitments g; data = { constraints = rows } }
     |> Stable.Latest.of_repr (Kimchi_bindings.Protocol.SRS.Fq.create 1) )
