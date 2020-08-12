open Core_kernel
open Pickles_types
open Common
module Ds = Domains

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
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t

  val of_int_exn : int -> t

  val zero : t

  open Impls.Step

  module Checked : sig
    type t

    val to_field : t -> Field.t
  end

  val typ : (Checked.t, t) Typ.t

  module Max : Nat.Add.Intf
end = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = char

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t

  let zero = Char.of_int_exn 0

  open Impls.Step
  module Length = Nat.N4

  module Checked = struct
    (* A "width" is represented by a 4 bit integer. *)
    type t = (Boolean.var, Length.n) Vector.t

    let to_field : t -> Field.t = Fn.compose Field.project Vector.to_list
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
    end
  end]

  type 'a t = 'a Stable.Latest.t = {h: 'a; k: 'a}
  [@@deriving hlist, sexp, fields]

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
            Backend.Tock.Curve.Affine.Stable.V1.t array Abc.Stable.V1.t
            Matrix_evals.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]
end

type t =
  { step_data: (Marlin_checks.Domain.t Domains.t * Width.t) Max_branches_vec.T.t
  ; max_width: Width.t
  ; wrap_index: Backend.Tock.Curve.Affine.t array Abc.t Matrix_evals.t
  ; wrap_vk: Impls.Wrap.Verification_key.t }

module Checked = struct
  open Step_main_inputs
  open Impl

  type t =
    { step_domains: (Field.t Domain.t Domains.t, Max_branches.n) Vector.t
    ; step_widths: (Width.Checked.t, Max_branches.n) Vector.t
    ; max_width: Width.Checked.t
    ; wrap_index: Inner_curve.t array Abc.t Matrix_evals.t
    ; num_branches: (Boolean.var, Max_branches.Log2.n) Vector.t }
  [@@deriving hlist]
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
          {h= Pow_2_roots_of_unity 0; k= Pow_2_roots_of_unity 0}
          Max_branches.n
      ; At_most.extend_to_vector
          (At_most.map step_data ~f:snd)
          Width.zero Max_branches.n
      ; max_width
      ; wrap_index
      ; (let n = At_most.length step_data in
         Vector.init Max_branches.Log2.n ~f:(fun i -> (n lsr i) land 1 = 1)) ]
      )
