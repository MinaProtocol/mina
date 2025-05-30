(** A verification key for a pickles proof, whose contents are not fixed within
    the verifier circuit.
    This is used to verify a proof where the verification key is determined by
    some other constraint, for example to use a verification key provided as
    input to the circuit, or loaded from an account that was chosen based upon
    the circuit inputs.

    Here and elsewhere, we use the terms
    * **width**:
      - the number of proofs that a proof has verified itself;
      - (equivalently) the maximum number of proofs that a proof depends upon
        directly.
      - NB: This does not include recursively-verified proofs, this only refers
        to proofs that were provided directly to pickles when the proof was
        being generated.
    * **branch**:
      - a single 'rule' or 'circuit' for which a proof can be generated, where
        a verification key verifies a proof for any of these branches.
      - It is common to have a 'base' branch and a 'recursion' branch. For
        example, the transaction snark has a 'transaction' proof that evaluates
        a single transaction and a 'merge' proof that combines two transaction
        snark proofs that prove sequential updates, each of which may be either
        a 'transaction' or a 'merge'.
*)

open Core_kernel
open Pickles_types
open Import
module V = Pickles_base.Side_loaded_verification_key

include (
  V :
    module type of V
      with module Width := V.Width
       and module Domains := V.Domains )

let bits = V.bits

module Width : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = V.Width.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  open Impls.Step

  module Checked : sig
    type t

    val to_field : t -> Field.t

    val to_bits : t -> Boolean.var list
  end

  val typ : (Checked.t, t) Typ.t

  module Max = Nat.N2

  module Max_vector : Vector.With_version(Max).S

  module Max_at_most : sig
    [%%versioned:
    module Stable : sig
      module V1 : sig
        type 'a t = ('a, Max.n) At_most.t
        [@@deriving compare, sexp, yojson, hash, equal]
      end
    end]
  end

  module Length : Nat.Add.Intf_transparent
end = struct
  include V.Width
  open Impls.Step

  module Checked = struct
    (* A "width" is represented by a 4 bit integer. *)
    type t = (Boolean.var, Length.n) Vector.t

    let to_field : t -> Field.t = Fn.compose Field.project Vector.to_list

    let to_bits = Vector.to_list
  end

  let typ : (Checked.t, t) Typ.t =
    Typ.transport
      (Vector.typ Boolean.typ Length.n)
      ~there:(fun x ->
        let x = to_int x in
        Vector.init Length.n ~f:(fun i -> (x lsr i) land 1 = 1) )
      ~back:(fun v ->
        Vector.foldi v ~init:0 ~f:(fun i acc b ->
            if b then acc lor (1 lsl i) else acc )
        |> of_int_exn )
end

module Domain = struct
  type 'a t = Pow_2_roots_of_unity of 'a [@@deriving sexp]

  let log2_size (Pow_2_roots_of_unity x) = x
end
[@@warning "-4"]

module Domains = struct
  include V.Domains

  let _typ =
    let open Impls.Step in
    let dom =
      Typ.transport Typ.field
        ~there:(fun (Plonk_checks.Domain.Pow_2_roots_of_unity n) ->
          Field.Constant.of_int n )
        ~back:(fun _ -> assert false)
      |> Typ.transport_var
           ~there:(fun (Domain.Pow_2_roots_of_unity n) -> n)
           ~back:(fun n -> Domain.Pow_2_roots_of_unity n)
    in
    Typ.of_hlistable [ dom ] ~var_to_hlist:to_hlist ~value_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_of_hlist:of_hlist
end

let max_domains =
  { Domains.h = Domain.Pow_2_roots_of_unity (Nat.to_int Backend.Tick.Rounds.n) }

module Vk = struct
  type t = (Impls.Wrap.Verification_key.t[@sexp.opaque]) [@@deriving sexp]

  let hash_fold_t s _ = Unit.hash_fold_t s ()
end

module R = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Backend.Tock.Curve.Affine.Stable.V1.t Repr.Stable.V2.t
      [@@deriving sexp, equal, compare, yojson]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned_binable
module Stable = struct
  module V2 = struct
    module T = struct
      type t =
        ( Backend.Tock.Curve.Affine.t
        , Pickles_base.Proofs_verified.Stable.V1.t
        , Vk.t )
        Poly.Stable.V2.t
      [@@deriving hash]

      let to_latest = Fn.id

      let description = "Verification key"

      let version_byte = Base58_check.Version_bytes.verification_key

      let to_repr
          { Poly.max_proofs_verified
          ; actual_wrap_domain_size
          ; wrap_index
          ; wrap_vk = _
          } =
        { Repr.Stable.V2.max_proofs_verified
        ; actual_wrap_domain_size
        ; wrap_index
        }

      let of_repr
          ({ Repr.Stable.V2.max_proofs_verified
           ; actual_wrap_domain_size
           ; wrap_index = c
           } :
            R.Stable.V2.t ) : t =
        let d =
          (Common.wrap_domains
             ~proofs_verified:
               (Pickles_base.Proofs_verified.to_int actual_wrap_domain_size) )
            .h
        in
        let log2_size = Import.Domain.log2_size d in
        let public =
          let (T (input, _conv, _conv_inv)) =
            Impls.Wrap.input ~feature_flags:Plonk_types.Features.Full.maybe ()
          in
          let (Typ typ) = input in
          typ.size_in_field_elements
        in
        (* we only compute the wrap_vk if the srs can be loaded *)
        let srs =
          try Some (Backend.Tock.Keypair.load_urs ()) with _ -> None
        in
        let wrap_vk =
          Option.map srs ~f:(fun srs : Impls.Wrap.Verification_key.t ->
              { domain =
                  { log_size_of_group = log2_size
                  ; group_gen = Backend.Tock.Field.domain_generator ~log2_size
                  }
              ; max_poly_size = 1 lsl Nat.to_int Backend.Tock.Rounds.n
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
              ; zk_rows = Plonk_checks.zk_rows_by_default
              } )
        in
        { Poly.max_proofs_verified
        ; actual_wrap_domain_size
        ; wrap_index = c
        ; wrap_vk
        }

      (* Proxy derivers to [R.t]'s, ignoring [wrap_vk] *)

      let sexp_of_t t = R.sexp_of_t (to_repr t)

      let t_of_sexp sexp = of_repr (R.t_of_sexp sexp)

      let _to_yojson t = R.to_yojson (to_repr t)

      let _of_yojson json = Result.map ~f:of_repr (R.of_yojson json)

      let equal x y = R.equal (to_repr x) (to_repr y)

      let compare x y = R.compare (to_repr x) (to_repr y)

      include
        Binable.Of_binable
          (R.Stable.V2)
          (struct
            type nonrec t = t

            let to_binable r = to_repr r

            let of_binable r = of_repr r
          end)
    end

    include T
    include Codable.Make_base58_check (T)
    include Codable.Make_base64 (T)
  end
end]

[%%define_locally
Stable.Latest.
  ( to_base58_check
  , of_base58_check
  , of_base58_check_exn
  , to_base64
  , of_base64
  , sexp_of_t
  , t_of_sexp
  , to_yojson
  , of_yojson
  , equal
  , compare )]

let dummy_wrap_vk :
    ( Pasta_bindings.Fq.t
    , Kimchi_bindings.Protocol.SRS.Fq.t
    , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm )
    Kimchi_types.VerifierIndex.verifier_index
    option
    Lazy.t =
  lazy
    (let d =
       (Common.wrap_domains
          ~proofs_verified:(Pickles_base.Proofs_verified.to_int N2) )
         .h
     in
     let log2_size = Import.Domain.log2_size d in
     let public =
       let (T (input, _conv, _conv_inv)) =
         Impls.Wrap.input ~feature_flags:Plonk_types.Features.Full.maybe ()
       in
       let (Typ typ) = input in
       typ.size_in_field_elements
     in
     (* we only compute the wrap_vk if the srs can be loaded *)
     let srs = try Some (Backend.Tock.Keypair.load_urs ()) with _ -> None in
     Option.map srs ~f:(fun srs : Impls.Wrap.Verification_key.t ->
         { domain =
             { log_size_of_group = log2_size
             ; group_gen = Backend.Tock.Field.domain_generator ~log2_size
             }
         ; max_poly_size = 1 lsl Nat.to_int Backend.Tock.Rounds.n
         ; public
         ; prev_challenges = 2 (* Due to Wrap_hack *)
         ; srs
         ; evals =
             (let x, y = Backend.Tock.Curve.(to_affine_exn one) in
              let g =
                { Kimchi_types.unshifted = [| Kimchi_types.Finite (x, y) |]
                ; shifted = None
                }
              in
              { sigma_comm =
                  Array.init (Nat.to_int Plonk_types.Permuts.n) ~f:(Fn.const g)
              ; coefficients_comm =
                  Array.init (Nat.to_int Plonk_types.Columns.n) ~f:(Fn.const g)
              ; generic_comm = g
              ; mul_comm = g
              ; psm_comm = g
              ; emul_comm = g
              ; complete_add_comm = g
              ; endomul_scalar_comm = g
              ; xor_comm = None
              ; range_check0_comm = None
              ; range_check1_comm = None
              ; foreign_field_add_comm = None
              ; foreign_field_mul_comm = None
              ; rot_comm = None
              } )
         ; shifts = Common.tock_shifts ~log2_size
         ; lookup_index = None
         ; zk_rows = 3
         } ) )

let dummy : t =
  { max_proofs_verified = N2
  ; actual_wrap_domain_size = N2
  ; wrap_index =
      (let g = Backend.Tock.Curve.(to_affine_exn one) in
       { sigma_comm = Vector.init Plonk_types.Permuts.n ~f:(fun _ -> g)
       ; coefficients_comm = Vector.init Plonk_types.Columns.n ~f:(fun _ -> g)
       ; generic_comm = g
       ; psm_comm = g
       ; complete_add_comm = g
       ; mul_comm = g
       ; emul_comm = g
       ; endomul_scalar_comm = g
       } )
  ; wrap_vk = None
  }

let dummy_with_wrap_vk = lazy { dummy with wrap_vk = Lazy.force dummy_wrap_vk }

module Checked = struct
  open Step_main_inputs

  type t =
    { max_proofs_verified : Pickles_base.Proofs_verified.One_hot.Checked.t
          (** The maximum of all of the [step_widths]. *)
    ; actual_wrap_domain_size : Pickles_base.Proofs_verified.One_hot.Checked.t
          (** The actual domain size used by the wrap circuit. *)
    ; wrap_index : Inner_curve.t Plonk_verification_key_evals.t
          (** The plonk verification key for the 'wrapping' proof that this key
              is used to verify.
          *)
    }
  [@@deriving hlist, fields]

  (** [log_2] of the width. *)
  let _width_size = Nat.to_int Width.Length.n

  let to_input =
    let open Random_oracle_input.Chunked in
    fun { max_proofs_verified; actual_wrap_domain_size; wrap_index } :
        _ Random_oracle_input.Chunked.t ->
      let max_proofs_verified =
        Pickles_base.Proofs_verified.One_hot.Checked.to_input
          max_proofs_verified
      in
      let actual_wrap_domain_size =
        Pickles_base.Proofs_verified.One_hot.Checked.to_input
          actual_wrap_domain_size
      in
      List.reduce_exn ~f:append
        [ max_proofs_verified
        ; actual_wrap_domain_size
        ; wrap_index_to_input
            (Fn.compose Array.of_list Inner_curve.to_field_elements)
            wrap_index
        ]
end

let typ : (Checked.t, t) Impls.Step.Typ.t =
  let open Step_main_inputs in
  let open Impl in
  Typ.of_hlistable
    [ Pickles_base.Proofs_verified.One_hot.typ
    ; Pickles_base.Proofs_verified.One_hot.typ
    ; Plonk_verification_key_evals.typ Inner_curve.typ
    ]
    ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
    ~value_of_hlist:(fun _ ->
      failwith "Side_loaded_verification_key: value_of_hlist" )
    ~value_to_hlist:(fun { Poly.wrap_index
                         ; actual_wrap_domain_size
                         ; max_proofs_verified
                         ; _
                         } ->
      [ max_proofs_verified; actual_wrap_domain_size; wrap_index ] )
