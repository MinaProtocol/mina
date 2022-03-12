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
open Common
open Import
module V = Pickles_base.Side_loaded_verification_key

include (
  V :
    module type of V
      with module Width := V.Width
       and module Domains := V.Domains )

let bits = V.bits

let input_size ~of_int ~add ~mul w =
  let open Composition_types in
  (* This should be an affine function in [a]. *)
  let size a =
    let (T (typ, conv)) =
      Impls.Step.input ~branching:a ~wrap_rounds:Backend.Tock.Rounds.n
    in
    Impls.Step.Data_spec.size [ typ ]
  in
  let f0 = size Nat.N0.n in
  let slope = size Nat.N1.n - f0 in
  add (of_int f0) (mul (of_int slope) w)

module Width : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = V.Width.Stable.V1.t
      [@@deriving sexp, equal, compare, hash, yojson]
    end
  end]

  val of_int_exn : int -> t

  val to_int : t -> int

  val to_bits : t -> bool list

  val zero : t

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
        Vector.init Length.n ~f:(fun i -> (x lsr i) land 1 = 1))
      ~back:(fun v ->
        Vector.foldi v ~init:0 ~f:(fun i acc b ->
            if b then acc lor (1 lsl i) else acc)
        |> of_int_exn)
end

module Domain = struct
  type 'a t = Pow_2_roots_of_unity of 'a [@@deriving sexp]

  let log2_size (Pow_2_roots_of_unity x) = x
end

module Domains = struct
  include V.Domains

  let typ =
    let open Impls.Step in
    let dom =
      Typ.transport Typ.field
        ~there:(fun (Plonk_checks.Domain.Pow_2_roots_of_unity n) ->
          Field.Constant.of_int n)
        ~back:(fun _ -> assert false)
      |> Typ.transport_var
           ~there:(fun (Domain.Pow_2_roots_of_unity n) -> n)
           ~back:(fun n -> Domain.Pow_2_roots_of_unity n)
    in
    Typ.of_hlistable [ dom ] ~var_to_hlist:to_hlist ~value_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_of_hlist:of_hlist
end

(* TODO: Probably better to have these match the step rounds. *)
let max_domains = { Domains.h = Domain.Pow_2_roots_of_unity 20 }

let max_domains_with_x =
  let conv (Domain.Pow_2_roots_of_unity n) =
    Plonk_checks.Domain.Pow_2_roots_of_unity n
  in
  let x =
    Plonk_checks.Domain.Pow_2_roots_of_unity
      (Int.ceil_log2
         (input_size ~of_int:Fn.id ~add:( + ) ~mul:( * )
            (Nat.to_int Width.Max.n)))
  in
  { Ds.h = conv max_domains.h; x }

module Vk = struct
  type t = (Impls.Wrap.Verification_key.t[@sexp.opaque]) [@@deriving sexp]

  let to_yojson _ = `String "opaque"

  let of_yojson _ = Error "Vk: yojson not supported"

  let hash _ = Unit.hash ()

  let hash_fold_t s _ = Unit.hash_fold_t s ()

  let equal _ _ = true

  let compare _ _ = 0
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
      type t = (Backend.Tock.Curve.Affine.t, Vk.t) Poly.Stable.V2.t
      [@@deriving hash]

      let to_latest = Fn.id

      let description = "Verification key"

      let version_byte = Base58_check.Version_bytes.verification_key

      let to_repr { Poly.step_data; max_width; wrap_index; wrap_vk = _ } =
        { Repr.Stable.V2.step_data; max_width; wrap_index }

      let of_repr
          ({ Repr.Stable.V2.step_data; max_width; wrap_index = c } :
            R.Stable.V2.t) : t =
        let d = Common.wrap_domains.h in
        let log2_size = Import.Domain.log2_size d in
        let max_quot_size = Common.max_quot_size_int (Import.Domain.size d) in
        let wrap_vk : Impls.Wrap.Verification_key.t =
          { domain =
              { log_size_of_group = log2_size
              ; group_gen = Backend.Tock.Field.domain_generator log2_size
              }
          ; max_poly_size = 1 lsl Nat.to_int Backend.Tock.Rounds.n
          ; max_quot_size
          ; srs = Backend.Tock.Keypair.load_urs ()
          ; evals =
              (let g (x, y) =
                 { Kimchi.Protocol.unshifted =
                     [| Kimchi.Foundations.Finite (x, y) |]
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
               ; chacha_comm = None
               })
          ; shifts = Common.tock_shifts ~log2_size
          ; lookup_index = None
          }
        in
        { Poly.step_data; max_width; wrap_index = c; wrap_vk = Some wrap_vk }

      (* Proxy derivers to [R.t]'s, ignoring [wrap_vk] *)

      let sexp_of_t t = R.sexp_of_t (to_repr t)

      let t_of_sexp sexp = of_repr (R.t_of_sexp sexp)

      let to_yojson t = R.to_yojson (to_repr t)

      let of_yojson json = Result.map ~f:of_repr (R.of_yojson json)

      let equal x y = R.equal (to_repr x) (to_repr y)

      let compare x y = R.compare (to_repr x) (to_repr y)

      include Binable.Of_binable
                (R.Stable.V2)
                (struct
                  type nonrec t = t

                  let to_binable r = to_repr r

                  let of_binable r = of_repr r
                end)
    end

    include T
    include Codable.Make_base58_check (T)
  end
end]

[%%define_locally
Stable.Latest.
  ( to_base58_check
  , of_base58_check
  , of_base58_check_exn
  , sexp_of_t
  , t_of_sexp
  , to_yojson
  , of_yojson
  , equal
  , compare )]

let dummy : t =
  { step_data = At_most.[]
  ; max_width = Width.zero
  ; wrap_index =
      (let g = Backend.Tock.Curve.(to_affine_exn one) in
       { sigma_comm = Vector.init Dlog_plonk_types.Permuts.n ~f:(fun _ -> g)
       ; coefficients_comm =
           Vector.init Dlog_plonk_types.Columns.n ~f:(fun _ -> g)
       ; generic_comm = g
       ; psm_comm = g
       ; complete_add_comm = g
       ; mul_comm = g
       ; emul_comm = g
       ; endomul_scalar_comm = g
       })
  ; wrap_vk = None
  }

module Checked = struct
  open Step_main_inputs
  open Impl

  type t =
    { step_domains : (Field.t Domain.t Domains.t, Max_branches.n) Vector.t
          (** The domain size for proofs of each branch. *)
    ; step_widths : (Width.Checked.t, Max_branches.n) Vector.t
          (** The width for for proofs of each branch. *)
    ; max_width : Width.Checked.t
          (** The maximum of all of the [step_widths]. *)
    ; wrap_index : Inner_curve.t Plonk_verification_key_evals.t
          (** The plonk verification key for the 'wrapping' proof that this key
              is used to verify.
          *)
    ; num_branches : (Boolean.var, Max_branches.Log2.n) Vector.t
          (** The number of branches, encoded as a bitstring. *)
    }
  [@@deriving hlist, fields]

  (** [log_2] of the width. *)
  let width_size = Nat.to_int Width.Length.n

  let to_input =
    let open Random_oracle_input.Chunked in
    let map_reduce t ~f = Array.map t ~f |> Array.reduce_exn ~f:append in
    fun { step_domains; step_widths; max_width; wrap_index; num_branches } :
        _ Random_oracle_input.Chunked.t ->
      let width w = (Width.Checked.to_field w, width_size) in
      List.reduce_exn ~f:append
        [ map_reduce (Vector.to_array step_domains) ~f:(fun { Domains.h } ->
              map_reduce [| h |] ~f:(fun (Domain.Pow_2_roots_of_unity x) ->
                  packed (x, max_log2_degree)))
        ; Array.map (Vector.to_array step_widths) ~f:width |> packeds
        ; packed (width max_width)
        ; wrap_index_to_input
            (Fn.compose Array.of_list Inner_curve.to_field_elements)
            wrap_index
        ; packed
            ( Field.project (Vector.to_list num_branches)
            , Nat.to_int Max_branches.Log2.n )
        ]
end

let%test_unit "input_size" =
  List.iter
    (List.range 0 (Nat.to_int Width.Max.n) ~stop:`inclusive ~start:`inclusive)
    ~f:(fun n ->
      [%test_eq: int]
        (input_size ~of_int:Fn.id ~add:( + ) ~mul:( * ) n)
        (let (T a) = Nat.of_int n in
         let (T (typ, conv)) =
           Impls.Step.input ~branching:a ~wrap_rounds:Backend.Tock.Rounds.n
         in
         Impls.Step.Data_spec.size [ typ ]))

let typ : (Checked.t, t) Impls.Step.Typ.t =
  let open Step_main_inputs in
  let open Impl in
  Typ.of_hlistable
    [ Vector.typ Domains.typ Max_branches.n
    ; Vector.typ Width.typ Max_branches.n
    ; Width.typ
    ; Plonk_verification_key_evals.typ Inner_curve.typ
    ; Vector.typ Boolean.typ Max_branches.Log2.n
    ]
    ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
    ~value_of_hlist:(fun _ ->
      failwith "Side_loaded_verification_key: value_of_hlist")
    ~value_to_hlist:(fun { Poly.step_data; wrap_index; max_width; _ } ->
      [ At_most.extend_to_vector
          (At_most.map step_data ~f:fst)
          dummy_domains Max_branches.n
      ; At_most.extend_to_vector
          (At_most.map step_data ~f:snd)
          dummy_width Max_branches.n
      ; max_width
      ; wrap_index
      ; (let n = At_most.length step_data in
         Vector.init Max_branches.Log2.n ~f:(fun i -> (n lsr i) land 1 = 1))
      ])
