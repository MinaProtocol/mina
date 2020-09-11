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
    Impls.Step.Data_spec.size [typ]
  in
  let f0 = size Nat.N0.n in
  let slope = size Nat.N1.n - f0 in
  add (of_int f0) (mul (of_int slope) w)

module Width : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = V.Width.Stable.V1.t [@@deriving sexp, eq, compare, hash, yojson]
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

  module Max : Nat.Add.Intf_transparent

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

module Domains = struct
  include V.Domains

  let typ =
    let open Impls.Step in
    let dom =
      Typ.transport Typ.field
        ~there:(fun (Marlin_checks.Domain.Pow_2_roots_of_unity n) ->
          Field.Constant.of_int n )
        ~back:(fun _ -> assert false)
      |> Typ.transport_var
           ~there:(fun (Domain.Pow_2_roots_of_unity n) -> n)
           ~back:(fun n -> Domain.Pow_2_roots_of_unity n)
    in
    Typ.of_hlistable [dom; dom] ~var_to_hlist:to_hlist ~value_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_of_hlist:of_hlist

  let iter {h; k} ~f = f h ; f k

  let map {h; k} ~f = {h= f h; k= f k}
end

(* TODO: Probably better to have these match the step rounds. *)
let max_domains =
  {Domains.h= Domain.Pow_2_roots_of_unity 20; k= Domain.Pow_2_roots_of_unity 20}

let max_domains_with_x =
  let conv (Domain.Pow_2_roots_of_unity n) =
    Marlin_checks.Domain.Pow_2_roots_of_unity n
  in
  let x =
    Marlin_checks.Domain.Pow_2_roots_of_unity
      (Int.ceil_log2
         ( 1
         + input_size ~of_int:Fn.id ~add:( + ) ~mul:( * )
             (Nat.to_int Width.Max.n) ))
  in
  {Ds.h= conv max_domains.h; k= conv max_domains.k; x}

module Vk = struct
  type t = Impls.Wrap.Verification_key.t sexp_opaque [@@deriving sexp]

  let to_yojson _ = `String "opaque"

  let of_yojson _ = Error "Vk: yojson not supported"

  let hash _ = Unit.hash ()

  let hash_fold_t s _ = Unit.hash_fold_t s ()

  let equal _ _ = true

  let compare _ _ = 0
end

include Make
          (Backend.Tock.Curve.Affine)
          (struct
            include Vk

            let of_repr {Repr.Stable.V1.step_data; max_width; wrap_index= c} =
              let u = Unsigned.Size_t.of_int in
              let g =
                Fn.compose
                  Zexe_backend.Tweedle.Fp_poly_comm
                  .without_degree_bound_to_backend Array.of_list
              in
              let t =
                let h = Import.Domain.size Common.wrap_domains.h in
                let k = Import.Domain.size Common.wrap_domains.k in
                Snarky_bn382.Tweedle.Dee.Field_verifier_index.make
                  (u
                     (input_size ~of_int:Fn.id ~add:( + ) ~mul:( * )
                        (Width.to_int max_width)))
                  (u h) (u h) (u k) (u Common.Max_degree.wrap)
                  (Zexe_backend.Tweedle.Dee_based.Keypair.load_urs ())
                  (g c.row.a) (g c.col.a) (g c.value.a) (g c.rc.a) (g c.row.b)
                  (g c.col.b) (g c.value.b) (g c.rc.b) (g c.row.c) (g c.col.c)
                  (g c.value.c) (g c.rc.c)
              in
              Caml.Gc.finalise
                Snarky_bn382.Tweedle.Dee.Field_verifier_index.delete t ;
              t
          end)

let dummy : t =
  { step_data= At_most.[]
  ; max_width= Width.zero
  ; wrap_index=
      (let g = [Backend.Tock.Curve.(to_affine_exn one)] in
       let t : _ Abc.t = {a= g; b= g; c= g} in
       {row= t; col= t; value= t; rc= t})
  ; wrap_vk= None }

module Checked = struct
  open Step_main_inputs
  open Impl

  type t =
    { step_domains: (Field.t Domain.t Domains.t, Max_branches.n) Vector.t
    ; step_widths: (Width.Checked.t, Max_branches.n) Vector.t
    ; max_width: Width.Checked.t
    ; wrap_index: Inner_curve.t array Abc.t Matrix_evals.t
    ; num_branches: (Boolean.var, Max_branches.Log2.n) Vector.t }
  [@@deriving hlist, fields]

  let to_input =
    let open Random_oracle_input in
    let map_reduce t ~f = Array.map t ~f |> Array.reduce_exn ~f:append in
    fun {step_domains; step_widths; max_width; wrap_index; num_branches} ->
      ( List.reduce_exn ~f:append
          [ map_reduce (Vector.to_array step_domains) ~f:(fun {Domains.h; k} ->
                map_reduce [|h; k|] ~f:(fun (Domain.Pow_2_roots_of_unity x) ->
                    bitstring (Field.unpack x ~length:max_log2_degree) ) )
          ; Array.map (Vector.to_array step_widths) ~f:Width.Checked.to_bits
            |> bitstrings
          ; bitstring (Width.Checked.to_bits max_width)
          ; wrap_index_to_input
              (Array.concat_map
                 ~f:(Fn.compose Array.of_list Inner_curve.to_field_elements))
              wrap_index
          ; bitstring (Vector.to_list num_branches) ]
        : _ Random_oracle_input.t )
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
         Impls.Step.Data_spec.size [typ]) )

let typ : (Checked.t, t) Impls.Step.Typ.t =
  let open Step_main_inputs in
  let open Impl in
  Typ.of_hlistable
    [ Vector.typ Domains.typ Max_branches.n
    ; Vector.typ Width.typ Max_branches.n
    ; Width.typ
    ; Matrix_evals.typ
        (Abc.typ
           (Typ.array Inner_curve.typ
              ~length:
                (index_commitment_length ~max_degree:Max_degree.wrap
                   Common.wrap_domains.k)))
    ; Vector.typ Boolean.typ Max_branches.Log2.n ]
    ~var_to_hlist:Checked.to_hlist ~var_of_hlist:Checked.of_hlist
    ~value_of_hlist:(fun _ ->
      failwith "Side_loaded_verification_key: value_of_hlist" )
    ~value_to_hlist:(fun {Poly.step_data; wrap_index; max_width; _} ->
      [ At_most.extend_to_vector
          (At_most.map step_data ~f:fst)
          dummy_domains Max_branches.n
      ; At_most.extend_to_vector
          (At_most.map step_data ~f:snd)
          dummy_width Max_branches.n
      ; max_width
      ; Matrix_evals.map ~f:(Abc.map ~f:Array.of_list) wrap_index
      ; (let n = At_most.length step_data in
         Vector.init Max_branches.Log2.n ~f:(fun i -> (n lsr i) land 1 = 1)) ]
      )
