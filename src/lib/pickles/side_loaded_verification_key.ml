open Core_kernel
open Pickles_types
open Common
module Ds = Domains

let bits ~len n = List.init len ~f:(fun i -> (n lsr i) land 1 = 1)

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
      type t [@@deriving sexp, eq, compare, hash, yojson]
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
end = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = char [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  let zero = Char.of_int_exn 0

  open Impls.Step
  module Length = Nat.N4

  module Checked = struct
    (* A "width" is represented by a 4 bit integer. *)
    type t = (Boolean.var, Length.n) Vector.t

    let to_field : t -> Field.t = Fn.compose Field.project Vector.to_list

    let to_bits = Vector.to_list
  end

  let typ =
    Typ.transport
      (Vector.typ Boolean.typ Length.n)
      ~there:(fun x ->
        let x = Char.to_int x in
        Vector.init Length.n ~f:(fun i -> (x lsr i) land 1 = 1) )
      ~back:(fun v ->
        Vector.foldi v ~init:0 ~f:(fun i acc b ->
            if b then acc lor (1 lsl i) else acc )
        |> Char.of_int_exn )

  module Max = Nat.N2

  let to_int = Char.to_int

  let to_bits = Fn.compose (bits ~len:(Nat.to_int Length.n)) to_int

  let of_int_exn : int -> t =
    let m = Nat.to_int Max.n in
    fun n ->
      assert (n <= m) ;
      Char.of_int_exn n
end

module Max_branches = struct
  include Nat.N8
  module Log2 = Nat.N3

  let%test "check max_branches" = Nat.to_int n = 1 lsl Nat.to_int Log2.n
end

module Domain = struct
  type 'a t = Pow_2_roots_of_unity of 'a [@@deriving sexp]

  let log2_size (Pow_2_roots_of_unity x) = x
end

module Domains = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = {h: 'a; k: 'a}
      [@@deriving sexp, eq, compare, hash, yojson, hlist, fields]
    end
  end]

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

module Max_branches_vec = struct
  module T = At_most.With_length (Max_branches)

  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = 'a T.t [@@deriving version {asserted}]
    end
  end]
end

module Repr = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { step_data:
            ( Marlin_checks.Domain.Stable.V1.t Domains.Stable.V1.t
            * Width.Stable.V1.t )
            Max_branches_vec.Stable.V1.t
        ; max_width: Width.Stable.V1.t
        ; wrap_index:
            Backend.Tock.Curve.Affine.Stable.V1.t list Abc.Stable.V1.t
            Matrix_evals.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]
end

module Vk = struct
  type t = Impls.Wrap.Verification_key.t sexp_opaque [@@deriving sexp]

  let to_yojson _ = `String "opaque"

  let of_yojson _ = Error "Vk: yojson not supported"

  let hash _ = Unit.hash ()

  let hash_fold_t s _ = Unit.hash_fold_t s ()

  let equal _ _ = true

  let compare _ _ = 0
end

let wrap_index_to_input (type gs f) (g : gs -> f array) =
  let open Random_oracle_input in
  let abc (t : gs Abc.t) : _ t =
    let [a; b; c] = Abc.to_hlist t in
    Array.concat_map [|a; b; c|] ~f:g |> field_elements
  in
  fun t ->
    let [x1; x2; x3; x4] = Matrix_evals.to_hlist t in
    List.map [x1; x2; x3; x4] ~f:abc |> List.reduce_exn ~f:append

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type t =
      { step_data:
          ( Marlin_checks.Domain.Stable.V1.t Domains.Stable.V1.t
          * Width.Stable.V1.t )
          Max_branches_vec.T.t
      ; max_width: Width.Stable.V1.t
      ; wrap_index:
          Backend.Tock.Curve.Affine.Stable.V1.t list Abc.Stable.V1.t
          Matrix_evals.Stable.V1.t
      ; wrap_vk: Vk.t option }
    [@@deriving sexp, eq, compare, hash, yojson]

    let to_latest = Fn.id

    include Binable.Of_binable
              (Repr.Stable.V1)
              (struct
                type nonrec t = t

                let to_binable {step_data; max_width; wrap_index; wrap_vk= _} =
                  {Repr.Stable.V1.step_data; max_width; wrap_index}

                let of_binable
                    {Repr.Stable.V1.step_data; max_width; wrap_index= c} =
                  { step_data
                  ; max_width
                  ; wrap_index= c
                  ; wrap_vk=
                      (let u = Unsigned.Size_t.of_int in
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
                           (g c.row.a) (g c.col.a) (g c.value.a) (g c.rc.a)
                           (g c.row.b) (g c.col.b) (g c.value.b) (g c.rc.b)
                           (g c.row.c) (g c.col.c) (g c.value.c) (g c.rc.c)
                       in
                       Caml.Gc.finalise
                         Snarky_bn382.Tweedle.Dee.Field_verifier_index.delete t ;
                       Some t) }
              end)
  end
end]

let dummy_domains =
  { Domains.h= Marlin_checks.Domain.Pow_2_roots_of_unity 0
  ; k= Pow_2_roots_of_unity 0 }

let dummy_width = Width.zero

let dummy : t =
  { step_data= At_most.[]
  ; max_width= Width.zero
  ; wrap_index=
      (let g = [Backend.Tock.Curve.(to_affine_exn one)] in
       let t : _ Abc.t = {a= g; b= g; c= g} in
       {row= t; col= t; value= t; rc= t})
  ; wrap_vk= None }

let to_input =
  let open Random_oracle_input in
  let map_reduce t ~f = Array.map t ~f |> Array.reduce_exn ~f:append in
  fun {step_data; max_width; wrap_index} ->
    ( let bits ~len n = bitstring (bits ~len n) in
      let num_branches =
        bits ~len:(Nat.to_int Max_branches.Log2.n) (At_most.length step_data)
      in
      let step_domains, step_widths =
        At_most.extend_to_vector step_data
          (dummy_domains, dummy_width)
          Max_branches.n
        |> Vector.unzip
      in
      List.reduce_exn ~f:append
        [ map_reduce (Vector.to_array step_domains) ~f:(fun {Domains.h; k} ->
              map_reduce [|h; k|] ~f:(fun (Pow_2_roots_of_unity x) ->
                  bits ~len:max_log2_degree x ) )
        ; Array.map (Vector.to_array step_widths) ~f:Width.to_bits
          |> bitstrings
        ; bitstring (Width.to_bits max_width)
        ; wrap_index_to_input
            (Fn.compose Array.of_list
               (List.concat_map ~f:(fun (x, y) -> [x; y])))
            wrap_index
        ; num_branches ]
      : _ Random_oracle_input.t )

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

let typ =
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
    ~value_to_hlist:(fun {step_data; wrap_index; max_width; _} ->
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
