open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let tests_enabled = true

let tuple5_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5 |] ->
      (a1, a2, a3, a4, a5)
  | _ ->
      assert false

let tuple21_of_array array =
  match array with
  | [| a1
     ; a2
     ; a3
     ; a4
     ; a5
     ; a6
     ; a7
     ; a8
     ; a9
     ; a10
     ; a11
     ; a12
     ; a13
     ; a14
     ; a15
     ; a16
     ; a17
     ; a18
     ; a19
     ; a20
     ; a21
    |] ->
      ( a1
      , a2
      , a3
      , a4
      , a5
      , a6
      , a7
      , a8
      , a9
      , a10
      , a11
      , a12
      , a13
      , a14
      , a15
      , a16
      , a17
      , a18
      , a19
      , a20
      , a21 )
  | _ ->
      assert false

(* 2^2L *)
let two_to_2limb = Bignum_bigint.(pow Common.two_to_limb (of_int 2))

let two_to_limb_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) =
  Common.(bignum_bigint_to_field (module Circuit) two_to_limb)

let two_to_2limb_field (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) =
  Common.(bignum_bigint_to_field (module Circuit) two_to_2limb)

(* Binary modulus *)
let binary_modulus = Common.two_to_3limb

(* Maximum foreign field modulus: see RFC for more details
 *   For simplicity and efficiency we use the approximation m = 2^259 - 1 *)
let max_foreign_field_modulus (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) :
    Bignum_bigint.t =
  Bignum_bigint.(pow (of_int 2) (of_int 259) - one)

(* Type of operation *)
type op_mode = Add | Sub

(* Foreign field modulus is abstract on two parameters
 *   - Field type
 *   - Limbs structure
 *
 *   There are 2 specific limb structures required
 *     - Standard mode : 3 limbs of L-bits each
 *     - Compact mode  : 2 limbs where the lowest is 2L bits and the highest is L bits
 *)

type 'field standard_limbs = 'field * 'field * 'field

type 'field compact_limbs = 'field * 'field

(* Convert Bignum_bigint.t to Bignum_bigint standard_limbs *)
let bignum_bigint_to_standard_limbs (bigint : Bignum_bigint.t) :
    Bignum_bigint.t standard_limbs =
  let l12, l0 = Common.(bignum_bigint_div_rem bigint two_to_limb) in
  let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
  (l0, l1, l2)

(* Convert Bignum_bigint.t to field standard_limbs *)
let bignum_bigint_to_field_const_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f standard_limbs =
  let l0, l1, l2 = bignum_bigint_to_standard_limbs bigint in
  ( Common.bignum_bigint_to_field (module Circuit) l0
  , Common.bignum_bigint_to_field (module Circuit) l1
  , Common.bignum_bigint_to_field (module Circuit) l2 )

(* Convert Bignum_bigint.t to Bignum_bigint compact_limbs *)
let bignum_bigint_to_compact_limbs (bigint : Bignum_bigint.t) :
    Bignum_bigint.t compact_limbs =
  let l2, l01 = Common.bignum_bigint_div_rem bigint two_to_2limb in
  (l01, l2)

(* Obtain the high limb of the input as a Bignum_bigint *)
let high_limb_of_bignum_bigint (bigint : Bignum_bigint.t) : Bignum_bigint.t =
  let _, high = bignum_bigint_to_compact_limbs bigint in
  high

(* Convert Bignum_bigint.t to field compact_limbs *)
let bignum_bigint_to_field_const_compact_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (bigint : Bignum_bigint.t) : f compact_limbs =
  let l01, l2 = bignum_bigint_to_compact_limbs bigint in
  ( Common.bignum_bigint_to_field (module Circuit) l01
  , Common.bignum_bigint_to_field (module Circuit) l2 )

(* Convert field standard_limbs to Bignum_bigint.t standard_limbs *)
let field_const_standard_limbs_to_bignum_bigint_standard_limbs (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_limbs : f standard_limbs) : Bignum_bigint.t standard_limbs =
  let l0, l1, l2 = field_limbs in
  ( Common.field_to_bignum_bigint (module Circuit) l0
  , Common.field_to_bignum_bigint (module Circuit) l1
  , Common.field_to_bignum_bigint (module Circuit) l2 )

(* Convert field standard_limbs to Bignum_bigint.t *)
let field_const_standard_limbs_to_bignum_bigint (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (field_limbs : f standard_limbs) : Bignum_bigint.t =
  let l0, l1, l2 =
    field_const_standard_limbs_to_bignum_bigint_standard_limbs
      (module Circuit)
      field_limbs
  in
  Bignum_bigint.(l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2))

(* Foreign field element interface *)
(* TODO: It would be better if this were created with functor that
 *       takes are arguments the native field and the foreign field modulus.
 *       Then when creating foreign field elements it could check that
 *       they are valid (less than the foreign field modulus).  We'd need a
 *       mode to override this last check for bound additions.
 *)
module type Element_intf = sig
  type 'field t

  type 'a limbs_type

  module Cvar = Snarky_backendless.Cvar

  (* Create foreign field element from Cvar limbs *)
  val of_limbs : 'field Cvar.t limbs_type -> 'field t

  (* Create foreign field element from field limbs *)
  val of_field_limbs :
       (module Snark_intf.Run with type field = 'field)
    -> 'field limbs_type
    -> 'field t

  (* Create foreign field element from Bignum_bigint.t *)
  val of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Create constant foreign field element from Bignum_bigint.t *)
  val const_of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Convert foreign field element into Cvar limbs *)
  val to_limbs : 'field t -> 'field Cvar.t limbs_type

  (* Map foreign field element's Cvar limbs into some other limbs with the mapping function func *)
  val map : 'field t -> ('field Cvar.t -> 'g) -> 'g limbs_type

  (* One constant *)
  val one : (module Snark_intf.Run with type field = 'field) -> 'field t

  (* Convert foreign field element into field limbs *)
  val to_field_limbs_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field limbs_type

  (* Convert foreign field element into Bignum_bigint.t limbs *)
  val to_bignum_bigint_limbs_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t limbs_type

  (* Convert foreign field element into a Bignum_bigint.t *)
  val to_bignum_bigint_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> Bignum_bigint.t

  (* Convert foreign field affine point to string *)
  val to_string_as_prover :
    (module Snark_intf.Run with type field = 'field) -> 'field t -> string

  (* Constrain zero check computation with boolean output *)
  val is_zero :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field Cvar.t Snark_intf.Boolean0.t

  (* Compare if two foreign field elements are equal *)
  val equal_as_prover :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field t
    -> bool

  (* Add copy constraints that two foreign field elements are equal *)
  val assert_equal :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> 'field t
    -> unit

  (* Create and constrain foreign field element from Bignum_bigint.t *)
  val check_here_const_of_bignum_bigint :
       (module Snark_intf.Run with type field = 'field)
    -> Bignum_bigint.t
    -> 'field t

  (* Add conditional constraints to select foreign field element *)
  val if_ :
       (module Snark_intf.Run with type field = 'field)
    -> 'field Cvar.t Snark_intf.Boolean0.t
    -> then_:'field t
    -> else_:'field t
    -> 'field t

  (* Decompose and constrain foreign field element into list of boolean cvars *)
  val unpack :
       (module Snark_intf.Run with type field = 'field)
    -> 'field t
    -> length:int
    -> 'field Cvar.t Snark_intf.Boolean0.t list
end

(* Foreign field element structures *)
module Element : sig
  (* Foreign field element (standard limbs) *)
  module Standard : sig
    include Element_intf with type 'a limbs_type = 'a standard_limbs

    (* Check that the foreign element is smaller than a given field modulus *)
    val fits_as_prover :
         (module Snark_intf.Run with type field = 'field)
      -> 'field t
      -> 'field standard_limbs
      -> bool
  end

  (* Foreign field element (compact limbs) *)
  module Compact : Element_intf with type 'a limbs_type = 'a compact_limbs
end = struct
  (* Standard limbs foreign field element *)
  module Standard = struct
    module Cvar = Snarky_backendless.Cvar

    type 'field limbs_type = 'field standard_limbs

    type 'field t = 'field Cvar.t standard_limbs

    let of_limbs x = x

    let of_field_limbs (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (x : field limbs_type) : field t =
      let open Circuit in
      let x =
        exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
            let x0, x1, x2 = x in
            [| x0; x1; x2 |] )
        |> Common.tuple3_of_array
      in
      of_limbs x

    let of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l12, l0 = Common.(bignum_bigint_div_rem x two_to_limb) in
      let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
      let limb_vars =
        exists (Typ.array ~length:3 Field.typ) ~compute:(fun () ->
            [| Common.bignum_bigint_to_field (module Circuit) l0
             ; Common.bignum_bigint_to_field (module Circuit) l1
             ; Common.bignum_bigint_to_field (module Circuit) l2
            |] )
      in
      of_limbs (limb_vars.(0), limb_vars.(1), limb_vars.(2))

    let const_of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l12, l0 = Common.(bignum_bigint_div_rem x two_to_limb) in
      let l2, l1 = Common.(bignum_bigint_div_rem l12 two_to_limb) in
      of_limbs
        Field.
          ( constant @@ Common.bignum_bigint_to_field (module Circuit) l0
          , constant @@ Common.bignum_bigint_to_field (module Circuit) l1
          , constant @@ Common.bignum_bigint_to_field (module Circuit) l2 )

    let to_limbs x = x

    let map (x : 'field t) (func : 'field Cvar.t -> 'g) : 'g limbs_type =
      let l0, l1, l2 = to_limbs x in
      (func l0, func l1, func l2)

    let to_field_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : field limbs_type =
      map x (Common.cvar_field_to_field_as_prover (module Circuit))

    let to_bignum_bigint_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t limbs_type =
      map x (Common.cvar_field_to_bignum_bigint_as_prover (module Circuit))

    let one (type field)
        (module Circuit : Snark_intf.Run with type field = field) : field t =
      of_bignum_bigint (module Circuit) Bignum_bigint.one

    let to_bignum_bigint_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t =
      let l0, l1, l2 = to_bignum_bigint_limbs_as_prover (module Circuit) x in
      Bignum_bigint.(l0 + (Common.two_to_limb * l1) + (two_to_2limb * l2))

    let to_string_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) a : string =
      sprintf "%s" @@ Bignum_bigint.to_string
      @@ to_bignum_bigint_as_prover (module Circuit) a

    let is_zero (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Circuit.Boolean.var =
      let open Circuit in
      let x0, x1, x2 = to_limbs x in
      let x0_is_zero = Field.(equal x0 zero) in
      let x1_is_zero = Field.(equal x1 zero) in
      let x2_is_zero = Field.(equal x2 zero) in
      Boolean.(x0_is_zero && x1_is_zero && x2_is_zero)

    let equal_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (left : field t) (right : field t) : bool =
      let open Circuit in
      let left0, left1, left2 =
        to_field_limbs_as_prover (module Circuit) left
      in
      let right0, right1, right2 =
        to_field_limbs_as_prover (module Circuit) right
      in
      Field.Constant.(
        equal left0 right0 && equal left1 right1 && equal left2 right2)

    let assert_equal (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (left : field t) (right : field t) : unit =
      let open Circuit in
      let left0, left1, left2 = to_limbs left in
      let right0, right1, right2 = to_limbs right in
      Field.Assert.equal left0 right0 ;
      Field.Assert.equal left1 right1 ;
      Field.Assert.equal left2 right2

    let check_here_const_of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let const_x = const_of_bignum_bigint (module Circuit) x in
      let var_x = of_bignum_bigint (module Circuit) x in
      assert_equal (module Circuit) const_x var_x ;
      const_x

    let fits_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        (modulus : field standard_limbs) : bool =
      let modulus =
        field_const_standard_limbs_to_bignum_bigint (module Circuit) modulus
      in
      Bignum_bigint.(to_bignum_bigint_as_prover (module Circuit) x < modulus)

    let if_ (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (b : Circuit.Boolean.var) ~(then_ : field t) ~(else_ : field t) :
        field t =
      let open Circuit in
      let then0, then1, then2 = to_limbs then_ in
      let else0, else1, else2 = to_limbs else_ in
      of_limbs
        ( Field.if_ b ~then_:then0 ~else_:else0
        , Field.if_ b ~then_:then1 ~else_:else1
        , Field.if_ b ~then_:then2 ~else_:else2 )

    let unpack (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        ~(length : int) : Circuit.Boolean.var list =
      let open Circuit in
      (* TODO: Performance improvement, we could use this trick from Halo paper
       * https://github.com/MinaProtocol/mina/blob/43e2994b64b9d3e99055d644ac6279d39c22ced5/src/lib/pickles/scalar_challenge.ml#L12
       *)
      let l0, l1, l2 = to_limbs x in
      fst
      @@ List.fold [ l0; l1; l2 ] ~init:([], length)
           ~f:(fun (lst, length) limb ->
             let bits_to_copy = min length Common.limb_bits in
             ( lst @ Field.unpack limb ~length:bits_to_copy
             , length - bits_to_copy ) )
  end

  (* Compact limbs foreign field element *)
  module Compact = struct
    module Cvar = Snarky_backendless.Cvar

    type 'field limbs_type = 'field compact_limbs

    type 'field t = 'field Cvar.t compact_limbs

    let of_limbs x = x

    let of_field_limbs (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (x : field limbs_type) : field t =
      let open Circuit in
      let x =
        exists Typ.(Field.typ * Field.typ) ~compute:(fun () -> (fst x, snd x))
      in
      of_limbs x

    let of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l2, l01 = Common.(bignum_bigint_div_rem x two_to_2limb) in

      let limb_vars =
        exists (Typ.array ~length:2 Field.typ) ~compute:(fun () ->
            [| Common.bignum_bigint_to_field (module Circuit) l01
             ; Common.bignum_bigint_to_field (module Circuit) l2
            |] )
      in
      of_limbs (limb_vars.(0), limb_vars.(1))

    let to_limbs x = x

    let const_of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let open Circuit in
      let l2, l01 = Common.(bignum_bigint_div_rem x two_to_2limb) in
      of_limbs
        Field.
          ( constant @@ Common.bignum_bigint_to_field (module Circuit) l01
          , constant @@ Common.bignum_bigint_to_field (module Circuit) l2 )

    let map (x : 'field t) (func : 'field Cvar.t -> 'g) : 'g limbs_type =
      let l0, l1 = to_limbs x in
      (func l0, func l1)

    let one (type field)
        (module Circuit : Snark_intf.Run with type field = field) : field t =
      of_bignum_bigint (module Circuit) Bignum_bigint.one

    let to_field_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : field limbs_type =
      map x (Common.cvar_field_to_field_as_prover (module Circuit))

    let to_bignum_bigint_limbs_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Bignum_bigint.t limbs_type =
      map x (Common.cvar_field_to_bignum_bigint_as_prover (module Circuit))

    let to_bignum_bigint_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        =
      let l01, l2 = to_bignum_bigint_limbs_as_prover (module Circuit) x in
      Bignum_bigint.(l01 + (two_to_2limb * l2))

    let to_string_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field) a : string =
      sprintf "%s" @@ Bignum_bigint.to_string
      @@ to_bignum_bigint_as_prover (module Circuit) a

    let is_zero (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        : Circuit.Boolean.var =
      let open Circuit in
      let x01, x2 = to_limbs x in
      let x01_is_zero = Field.(equal x01 zero) in
      let x2_is_zero = Field.(equal x2 zero) in
      Boolean.(x01_is_zero && x2_is_zero)

    let equal_as_prover (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (left : field t) (right : field t) : bool =
      let open Circuit in
      let left01, left2 = to_field_limbs_as_prover (module Circuit) left in
      let right01, right2 = to_field_limbs_as_prover (module Circuit) right in
      Field.Constant.(equal left01 right01 && equal left2 right2)

    let assert_equal (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (left : field t) (right : field t) : unit =
      let open Circuit in
      let left01, left2 = to_limbs left in
      let right01, right2 = to_limbs right in
      Field.Assert.equal left01 right01 ;
      Field.Assert.equal left2 right2

    let check_here_const_of_bignum_bigint (type field)
        (module Circuit : Snark_intf.Run with type field = field) x : field t =
      let const_x = const_of_bignum_bigint (module Circuit) x in
      let var_x = of_bignum_bigint (module Circuit) x in
      assert_equal (module Circuit) const_x var_x ;
      const_x

    let if_ (type field)
        (module Circuit : Snark_intf.Run with type field = field)
        (b : Circuit.Boolean.var) ~(then_ : field t) ~(else_ : field t) :
        field t =
      let open Circuit in
      let then01, then2 = to_limbs then_ in
      let else01, else2 = to_limbs else_ in
      of_limbs
        ( Field.if_ b ~then_:then01 ~else_:else01
        , Field.if_ b ~then_:then2 ~else_:else2 )

    let unpack (type field)
        (module Circuit : Snark_intf.Run with type field = field) (x : field t)
        ~(length : int) : Circuit.Boolean.var list =
      (* TODO: Performance improvement, we could use this trick from Halo paper
       * https://github.com/MinaProtocol/mina/blob/43e2994b64b9d3e99055d644ac6279d39c22ced5/src/lib/pickles/scalar_challenge.ml#L12
       *)
      let open Circuit in
      let l01, l2 = to_limbs x in
      fst
      @@ List.foldi [ l01; l2 ] ~init:([], length)
           ~f:(fun i (lst, length) limb ->
             let bits_to_copy = min length ((2 - i) * Common.limb_bits) in
             ( lst @ Field.unpack limb ~length:bits_to_copy
             , length - bits_to_copy ) )
  end
end

(* Structure for tracking external checks that must be made
 * (using other gadgets) in order to acheive soundess for a
 * given multiplication *)
module External_checks = struct
  module Cvar = Snarky_backendless.Cvar

  type 'field t =
    { mutable bounds : ('field Cvar.t standard_limbs * bool) list
    ; mutable canonicals : 'field Cvar.t standard_limbs list
    ; mutable multi_ranges : 'field Cvar.t standard_limbs list
    ; mutable compact_multi_ranges : 'field Cvar.t compact_limbs list
    ; mutable limb_ranges : 'field Cvar.t list
    }

  (* Create a new context *)
  let create (type field)
      (module Circuit : Snark_intf.Run with type field = field) : field t =
    { bounds = []
    ; canonicals = []
    ; multi_ranges = []
    ; compact_multi_ranges = []
    ; limb_ranges = []
    }

  (* Track a bound check *)
  let append_bound_check (external_checks : 'field t)
      ?(do_multi_range_check = true) (x : 'field Element.Standard.t) =
    external_checks.bounds <-
      (Element.Standard.to_limbs x, do_multi_range_check)
      :: external_checks.bounds

  (* Track a canonical check *)
  let append_canonical_check (external_checks : 'field t)
      (x : 'field Element.Standard.t) =
    external_checks.canonicals <-
      Element.Standard.to_limbs x :: external_checks.canonicals

  (* Track a multi-range-check *)
  (* TODO: improve names of these from append_ to add_, push_ or insert_ *)
  let append_multi_range_check (external_checks : 'field t)
      (x : 'field Cvar.t standard_limbs) =
    external_checks.multi_ranges <- x :: external_checks.multi_ranges

  (* Track a compact-multi-range-check *)
  let append_compact_multi_range_check (external_checks : 'field t)
      (x : 'field Cvar.t compact_limbs) =
    external_checks.compact_multi_ranges <-
      x :: external_checks.compact_multi_ranges

  (* Tracks a limb-range-check *)
  let append_limb_check (external_checks : 'field t) (x : 'field Cvar.t) =
    external_checks.limb_ranges <- x :: external_checks.limb_ranges
end

(* Common auxiliary functions for foreign field gadgets *)

(* Check that the foreign modulus is less than the maximum allowed *)
let check_modulus_bignum_bigint (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (foreign_field_modulus : Bignum_bigint.t) =
  (* Note that the maximum foreign field modulus possible for addition is much
   * larger than that supported by multiplication.
   *
   * Specifically, since the 88-bit limbs are embedded in a native field element
   * of ~2^255 bits and foreign field addition increases the number of bits
   * logarithmically, for addition we can actually support a maximum field modulus
   * of 2^264 - 1 (i.e. binary_modulus - 1) for circuits up to length ~ 2^79 - 1,
   * which is far larger than the maximum circuit size supported by Kimchi.
   *
   * However, for compatibility with multiplication operations, we must use the
   * same maximum as foreign field multiplication.
   *)
  assert (
    Bignum_bigint.(
      foreign_field_modulus < max_foreign_field_modulus (module Circuit)) )

(* Check that the foreign modulus is less than the maximum allowed *)
let check_modulus (type f) (module Circuit : Snark_intf.Run with type field = f)
    (foreign_field_modulus : f standard_limbs) =
  let foreign_field_modulus =
    field_const_standard_limbs_to_bignum_bigint
      (module Circuit)
      foreign_field_modulus
  in

  check_modulus_bignum_bigint (module Circuit) foreign_field_modulus

(* Gadget for creating an addition or subtraction result row (Zero gate with result) *)
let result_row (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(label = "result_row") (result1 : f Element.Standard.t)
    (result2 : f Element.Standard.t option) =
  let open Circuit in
  let result1_0, result1_1, result1_2 = Element.Standard.to_limbs result1 in
  with_label label (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Raw
                 { kind = Zero
                 ; values =
                     ( match result2 with
                     | None ->
                         [| result1_0; result1_1; result1_2 |]
                     | Some result2 ->
                         let result2_0, result2_1, result2_2 =
                           Element.Standard.to_limbs result2
                         in
                         [| result1_0
                          ; result1_1
                          ; result1_2
                          ; result2_0
                          ; result2_1
                          ; result2_2
                         |] )
                 ; coeffs = [||]
                 } )
        } )

(* Represents two limbs as one single field element with twice as many bits *)
let as_prover_compact_limb (type f)
    (module Circuit : Snark_intf.Run with type field = f) (lo : f) (hi : f) : f
    =
  Circuit.Field.Constant.(lo + (hi * two_to_limb_field (module Circuit)))

(* Internal foreign field addition helper *)
let sum_setup (type f) (module Circuit : Snark_intf.Run with type field = f)
    ~(final : bool) (left_input : f Element.Standard.t)
    (right_input : f Element.Standard.t) (operation : op_mode)
    (foreign_field_modulus : f standard_limbs) :
    f Element.Standard.t * f * Circuit.Field.t =
  let open Circuit in
  (* Decompose modulus into limbs *)
  let foreign_field_modulus0, foreign_field_modulus1, foreign_field_modulus2 =
    foreign_field_modulus
  in
  (* Decompose left input into limbs *)
  let left_input0, left_input1, left_input2 =
    Element.Standard.to_limbs left_input
  in
  (* Decompose right input into limbs. If final check, right_input2 will contain 2^limb *)
  let right_input0, right_input1, right_input2 =
    Element.Standard.to_limbs right_input
  in

  (* Addition or subtraction *)
  let sign =
    match operation with
    | Sub ->
        Field.Constant.(negate one)
    | Add ->
        Field.Constant.one
  in

  (* Given a left and right inputs to an addition or subtraction, and a modulus, it computes
   * all necessary values needed for the witness layout. Meaning, it returns an [FFAddValues] instance
   *     - the result of the addition/subtraction as a ForeignElement
   *     - the sign of the operation
   *     - the overflow flag
   *     - the carry value *)
  let result0, result1, result2, field_overflow, carry =
    exists (Typ.array ~length:5 Field.typ) ~compute:(fun () ->
        (* Compute bigint version of the inputs *)
        let modulus =
          field_const_standard_limbs_to_bignum_bigint
            (module Circuit)
            foreign_field_modulus
        in
        let left =
          Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            left_input
        in
        let right =
          Element.Standard.to_bignum_bigint_as_prover
            (module Circuit)
            right_input
        in

        (* Compute values for the ffadd *)

        (* Overflow if addition and greater than modulus or
         * underflow if subtraction and less than zero
         *)
        let has_overflow =
          match operation with
          | Sub ->
              Bignum_bigint.(left < right)
          | Add ->
              Bignum_bigint.(left + right >= modulus)
        in

        (* 0 for no overflow
         * -1 for underflow
         * +1 for overflow
         *)
        let field_overflow =
          if has_overflow then sign else Field.Constant.zero
        in

        (* Compute the result
         * result = left + sign * right - field_overflow * modulus
         * TODO: unluckily, we cannot do it in one line if we keep these types, because one
         *       cannot combine field elements and biguints in the same operation automatically
         *)
        let is_sub = match operation with Sub -> true | Add -> false in
        let result =
          Element.Standard.of_bignum_bigint (module Circuit)
          @@ Bignum_bigint.(
               if is_sub then
                 if not has_overflow then (* normal subtraction *)
                   left - right
                 else (* underflow *)
                   modulus + left - right
               else if not has_overflow then (* normal addition *)
                 left + right
               else (* overflow *)
                 left + right - modulus)
        in

        (* c = [ (a1 * 2^88 + a0) + s * (b1 * 2^88 + b0) - q * (f1 * 2^88 + f0) - (r1 * 2^88 + r0) ] / 2^176
         *  <=>
         * c = r2 - a2 - s*b2 + q*f2 *)
        let left_input0, left_input1, left_input2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) left_input
        in
        let right_input0, right_input1, right_input2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) right_input
        in
        let result0, result1, result2 =
          Element.Standard.to_field_limbs_as_prover (module Circuit) result
        in

        (* Compute the carry value *)
        let carry_bot =
          Field.Constant.(
            ( as_prover_compact_limb (module Circuit) left_input0 left_input1
            + as_prover_compact_limb (module Circuit) right_input0 right_input1
              * sign
            - as_prover_compact_limb
                (module Circuit)
                foreign_field_modulus0 foreign_field_modulus1
              * field_overflow
            - as_prover_compact_limb (module Circuit) result0 result1 )
            / two_to_2limb_field (module Circuit))
        in

        let carry_top =
          Field.Constant.(
            result2 - left_input2 - (sign * right_input2)
            + (field_overflow * foreign_field_modulus2))
        in

        (* Check that both ways of computing the carry value are equal *)
        assert (Field.Constant.equal carry_top carry_bot) ;

        (* Return the ffadd values *)
        [| result0; result1; result2; field_overflow; carry_bot |] )
    |> tuple5_of_array
  in

  (* Create the gate *)
  with_label "ffadd_gate" (fun () ->
      (* Set up ForeignFieldAdd gate *)
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldAdd
                 { left_input_lo = left_input0
                 ; left_input_mi = left_input1
                 ; left_input_hi = left_input2
                 ; right_input_lo = right_input0
                 ; right_input_mi = right_input1
                 ; right_input_hi = right_input2
                 ; field_overflow
                 ; carry
                 ; foreign_field_modulus0
                 ; foreign_field_modulus1
                 ; foreign_field_modulus2
                 ; sign
                 } )
        } ) ;

  let result = Element.Standard.of_limbs (result0, result1, result2) in

  if final then
    (* Create the result row *)
    result_row (module Circuit) ~label:"result_row" result None ;

  (* Return the result *)
  (result, sign, field_overflow)

(** Gadget for a chain of foreign field sums (additions or subtractions)
 *
 *    Inputs:
 *      inputs                := All the inputs to the chain of sums
 *      operations            := List of operation modes Add or Sub indicating whether the
 *                               corresponding addition is a subtraction
 *      foreign_field_modulus := Foreign field modulus
 *
 *    Outputs:
 *      Inserts ForeignFieldAdd gate into the circuit
 *      Returns the final result of the chain of sums
 *
 *    For n+1 inputs, the gadget creates n foreign field addition gates.
 *
 * TODO:
 *    Understand if concatenating sums is possible with input limbs < 2^88 with chunking
 *)
let sum_chain (type f) (module Circuit : Snark_intf.Run with type field = f)
    (inputs : f Element.Standard.t list) (operations : op_mode list)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let open Circuit in
  (* Check foreign field modulus < max allowed *)
  check_modulus (module Circuit) foreign_field_modulus ;
  (* Check that the number of inputs is correct *)
  let n = List.length operations in
  assert (List.length inputs = n + 1) ;

  (* Initialize first left input and check it fits in the foreign mod *)
  let left = [| List.hd_exn inputs |] in
  as_prover (fun () ->
      assert (
        Element.Standard.fits_as_prover
          (module Circuit)
          left.(0) foreign_field_modulus ) ;
      () ) ;

  (* For all n additions, compute its values and create gates *)
  for i = 0 to n - 1 do
    let op = List.nth_exn operations i in
    let right = List.nth_exn inputs (i + 1) in
    (* Make sure that inputs are smaller than the foreign modulus *)
    as_prover (fun () ->
        assert (
          Element.Standard.fits_as_prover
            (module Circuit)
            right foreign_field_modulus ) ;
        () ) ;

    (* Create the foreign field addition row *)
    let result, _sign, _ovf =
      sum_setup
        (module Circuit)
        ~final:false left.(0) right op foreign_field_modulus
    in

    (* Update left input for next iteration *)
    left.(0) <- result ; ()
  done ;

  let result = left.(0) in

  (* Return result *)
  result

(* Definition of a gadget for a single foreign field addition
 *
 *    Inputs:
 *      final                 := Whether it is the final operation of a chain.
 *                               Default is false (does not add final result row)
 *      left_input            := Foreign field element
 *      right_input           := Foreign field element
 *      foreign_field_modulus := Foreign field modulus
 *
 *    Outputs:
 *      Inserts ForeignFieldAdd gate into the circuit
 *      Returns the result
 *)
let add (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(final = false) (left_input : f Element.Standard.t)
    (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let final = match final with true -> true | false -> false in
  let result, _sign, _ovf =
    sum_setup
      (module Circuit)
      ~final left_input right_input Add foreign_field_modulus
  in
  result

(* Definition of a gadget for a single foreign field subtraction
 *
 *    Inputs:
 *      final                 := Whether it is the final operation of a chain.
 *                               Default is false (does not add final result row)
 *      left_input            := Foreign field element
 *      right_input           := Foreign field element
 *      foreign_field_modulus := Foreign field modulus
 *
 *    Outputs:
 *      Inserts ForeignFieldAdd gate into the circuit
 *      Returns ther result
 *)
let sub (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(final = true) (left_input : f Element.Standard.t)
    (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let final = match final with true -> true | false -> false in
  let result, _sign, _ovf =
    sum_setup
      (module Circuit)
      ~final left_input right_input Sub foreign_field_modulus
  in
  result

(* Bound check the supplied value
 *    Inputs:
 *      external_checks       := Context to track required external checks
 *      x                     := Value to check
 *      do_multi_range_check  := Whether to multi-range-check x
 *      foreign_field_modulus := Foreign field modulus
 *
 *    Outputs:
 *      Inserts generic gate to constrain computation of high bound x'2 = x2 + 2^88 - f2 - 1
 *      Adds x to external_checks.multi_ranges
 *      Adds x'2 to external_checks.limb_ranges
 *      Returns computed high bound
 *)
let check_bound (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f External_checks.t) (x : f Element.Standard.t)
    (do_multi_range_check : bool) (foreign_field_modulus : f standard_limbs) :
    Circuit.Field.t =
  let open Circuit in
  let _, _, foreign_field_modulus2 = foreign_field_modulus in
  let x0, x1, x2 = Element.Standard.to_limbs x in

  (* Compute constant term: 2^88 - f2 - 1 *)
  let foreign_field_modulus2 =
    Common.field_to_bignum_bigint (module Circuit) foreign_field_modulus2
  in
  let const_term =
    Field.constant
    @@ Common.bignum_bigint_to_field (module Circuit)
    @@ Bignum_bigint.(Common.two_to_limb - foreign_field_modulus2 - one)
  in

  (* Compute high limb bound: x'2 = x2 + (2^88 - f2 - 1) *)
  let x2_bound = Field.(x2 + const_term) in

  if do_multi_range_check then
    (* Add external multi-range-check x *)
    External_checks.append_multi_range_check external_checks (x0, x1, x2) ;

  (* Add external limb-check x *)
  External_checks.append_limb_check external_checks x2_bound ;

  x2_bound

(* Gadget to check the supplied value is a canonical foreign field element for the
 * supplied foreign field modulus
 *
 *    This gadget checks in the circuit that a value is less than the foreign field modulus.
 *    Part of this involves computing a bound value that is both added to external_checks
 *    and also returned.  The caller may use either one, depending on the situation.
 *
 *    Inputs:
 *      external_checks       := Context to track required external checks
 *      value                 := Value to check
 *      foreign_field_modulus := Foreign field modulus
 *
 *    Outputs:
 *      Inserts ForeignFieldAdd gate
 *      Inserts Zero gate containing result
 *      Adds bound to be multi-range-checked to external_checks
 *      Returns bound value
 *)
let check_canonical (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f External_checks.t) (value : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let open Circuit in
  (* Compute the value for the right input of the addition as 2^264 *)
  let offset0 = Field.zero in
  let offset1 = Field.zero in
  let offset2 =
    exists Field.typ ~compute:(fun () -> two_to_limb_field (module Circuit))
  in
  (* Checks that these cvars have constant values are added as generics *)
  let offset = Element.Standard.of_limbs (offset0, offset1, offset2) in

  (* Check that the value fits in the foreign field *)
  as_prover (fun () ->
      assert (
        Element.Standard.fits_as_prover
          (module Circuit)
          value foreign_field_modulus ) ;
      () ) ;

  (* Create FFAdd gate to compute the bound value (i.e. part of check_canonical)
     and creates the result row afterwards *)
  let bound, sign, ovf =
    sum_setup
      (module Circuit)
      ~final:true value offset Add foreign_field_modulus
  in

  (* Sanity check *)
  as_prover (fun () ->
      (* Check that the correct expected values were obtained *)
      let ovf = Common.cvar_field_to_field_as_prover (module Circuit) ovf in
      assert (Field.Constant.(equal sign one)) ;
      assert (Field.Constant.(equal ovf one)) ) ;

  (* Set up copy constraints with overflow with the overflow check *)
  Field.Assert.equal ovf Field.one ;

  (* Check that the highest limb of right input is 2^88 *)
  let two_to_88 = two_to_limb_field (module Circuit) in
  Field.Assert.equal (Field.constant two_to_88) offset2 ;

  (* Add external check to multi range check the bound *)
  External_checks.append_multi_range_check external_checks
  @@ Element.Standard.to_limbs bound ;

  (* Return the bound value *)
  bound

(* Gadget to constrain external checks using supplied modulus *)
let constrain_external_checks (type field)
    (module Circuit : Snark_intf.Run with type field = field)
    (external_checks : field External_checks.t)
    (foreign_field_modulus : field standard_limbs) =
  let open Circuit in
  (* 1) Insert gates for bound checks
   *    Note: internally this also adds a limb-check for the computed bound to
   *          external_checks.limb_ranges and optionally adds a multi-range-check
   *          for the original value to external_checks.multi_ranges.
   *          These are subsequently constrainted in (5) and (2) below.
   *)
  List.iter external_checks.bounds ~f:(fun (value, do_multi_range_check) ->
      let _bound =
        check_bound
          (module Circuit)
          external_checks
          (Element.Standard.of_limbs value)
          do_multi_range_check foreign_field_modulus
      in
      () ) ;

  (* 2) Insert gates for canonical checks
   *    Note: internally this also adds a multi-range-check for the computed bound to
   *          external_checks.multi_ranges.
   *          These are subsequently constrainted in (2) below.
   *)
  List.iter external_checks.canonicals ~f:(fun value ->
      let _bound =
        check_canonical
          (module Circuit)
          external_checks
          (Element.Standard.of_limbs value)
          foreign_field_modulus
      in
      () ) ;

  (* 3) Add gates for external multi-range-checks *)
  List.iter external_checks.multi_ranges ~f:(fun multi_range ->
      let v0, v1, v2 = multi_range in
      Range_check.multi (module Circuit) v0 v1 v2 ;
      () ) ;

  (* 4) Add gates for external compact-multi-range-checks *)
  List.iter external_checks.compact_multi_ranges ~f:(fun compact_multi_range ->
      let v01, v2 = compact_multi_range in
      let _v0, _v1 = Range_check.compact_multi (module Circuit) v01 v2 in
      () ) ;

  (* 5) Add gates for external limb-range-checks *)
  List.iter (List.chunks_of external_checks.limb_ranges ~length:3)
    ~f:(fun chunk ->
      match chunk with
      | [ v0 ] ->
          Range_check.multi (module Circuit) v0 Field.zero Field.zero
      | [ v0; v1 ] ->
          Range_check.multi (module Circuit) v0 v1 Field.zero
      | [ v0; v1; v2 ] ->
          Range_check.multi (module Circuit) v0 v1 v2
      | _ ->
          assert false )

(* Compute non-zero intermediate products (foreign field multiplication helper)
 *
 *   For more details see the "Intermediate products" Section of
 *   the [Foreign Field Multiplication RFC](https://o1-labs.github.io/proof-systems/rfcs/foreign_field_mul.html)
 *
 *   Preconditions: this entire function is witness code and, therefore, must be
 *                  only called from an exists construct.
 *)
let compute_intermediate_products (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Element.Standard.t) (right_input : f Element.Standard.t)
    (quotient : f standard_limbs) (neg_foreign_field_modulus : f standard_limbs)
    : f * f * f =
  let open Circuit in
  let left_input0, left_input1, left_input2 =
    Element.Standard.to_field_limbs_as_prover (module Circuit) left_input
  in
  let right_input0, right_input1, right_input2 =
    Element.Standard.to_field_limbs_as_prover (module Circuit) right_input
  in
  let quotient0, quotient1, quotient2 = quotient in
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    neg_foreign_field_modulus
  in
  ( (* p0 = a0 * b0 + q0 + f'0 *)
    Field.Constant.(
      (left_input0 * right_input0) + (quotient0 * neg_foreign_field_modulus0))
  , (* p1 = a0 * b1 + a1 * b0 + q0 * f'1 + q1 * f'0 *)
    Field.Constant.(
      (left_input0 * right_input1)
      + (left_input1 * right_input0)
      + (quotient0 * neg_foreign_field_modulus1)
      + (quotient1 * neg_foreign_field_modulus0))
  , (* p2 = a0 * b2 + a2 * b0 + a1 * b1 - q0 * f'2 + q2 * f'0 + q1 * f'1 *)
    Field.Constant.(
      (left_input0 * right_input2)
      + (left_input2 * right_input0)
      + (left_input1 * right_input1)
      + (quotient0 * neg_foreign_field_modulus2)
      + (quotient2 * neg_foreign_field_modulus0)
      + (quotient1 * neg_foreign_field_modulus1)) )

(* Perform integer bound computation for high limb x'2 = x2 + 2^l - f2 - 1 *)
let compute_high_bound (x : Bignum_bigint.t)
    (foreign_field_modulus : Bignum_bigint.t) : Bignum_bigint.t =
  let x_hi = high_limb_of_bignum_bigint x in
  let fmod_hi = high_limb_of_bignum_bigint foreign_field_modulus in
  let limb_hi = Bignum_bigint.(Common.two_to_limb - fmod_hi - one) in
  let x_bound_hi = Bignum_bigint.(x_hi + limb_hi) in
  assert (Bignum_bigint.(x_bound_hi < Common.two_to_limb)) ;
  x_bound_hi

(* Perform integer bound addition for all limbs x' = x + f' *)
let _compute_bound (x : Bignum_bigint.t)
    (neg_foreign_field_modulus : Bignum_bigint.t) : Bignum_bigint.t =
  let x_bound = Bignum_bigint.(x + neg_foreign_field_modulus) in
  assert (Bignum_bigint.(x_bound < binary_modulus)) ;
  x_bound

(* Compute witness variables related for foreign field multplication *)
let compute_witness_variables (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (products : Bignum_bigint.t standard_limbs)
    (remainder : Bignum_bigint.t standard_limbs) : f * f * f * f * f =
  let products0, products1, products2 = products in
  let remainder0, remainder1, remainder2 = remainder in

  (* C1,C3: Compute components of product1 *)
  let product1_hi, product1_lo =
    Common.(bignum_bigint_div_rem products1 two_to_limb)
  in
  let product1_hi_1, product1_hi_0 =
    Common.(bignum_bigint_div_rem product1_hi two_to_limb)
  in

  (* C2,C4: Compute v0 = the top 2 bits of (p0 + 2^L * p10 - r0 - 2^L * r1) / 2^2L
   *   N.b. To avoid an underflow error, the equation must sum the intermediate
   *        product terms before subtracting limbs of the remainder. *)
  let carry0 =
    Bignum_bigint.(
      ( products0
      + (Common.two_to_limb * product1_lo)
      - remainder0
      - (Common.two_to_limb * remainder1) )
      / two_to_2limb)
  in

  (* C6-C10: Compute v1 = the top L + 3 bits (p2 + p11 + v0 - r2) / 2^L
   *   N.b. Same as above, to avoid an underflow error, the equation must
   *        sum the intermediate product terms before subtracting the remainder. *)
  let carry1 =
    Bignum_bigint.(
      (products2 + product1_hi + carry0 - remainder2) / Common.two_to_limb)
  in

  (* C5: witness data a, b, q, and r already present *)
  ( Common.bignum_bigint_to_field (module Circuit) product1_lo
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_0
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_1
  , Common.bignum_bigint_to_field (module Circuit) carry0
  , Common.bignum_bigint_to_field (module Circuit) carry1 )

(* Foreign field multiplication gadget definition *)
let mul (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f External_checks.t) (left_input : f Element.Standard.t)
    (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let open Circuit in
  let of_bits = Common.field_bits_le_to_field (module Circuit) in

  (* Check foreign field modulus < max allowed *)
  check_modulus (module Circuit) foreign_field_modulus ;

  (*
   * Compute gate coefficients (happens when circuit is created)
   *)

  (* Get high limb of foreign field modulus (coefficient) *)
  let _, _, foreign_field_modulus2 = foreign_field_modulus in

  (* Compute foreign field modulus as bigint (used here and it witness generation) *)
  let foreign_field_modulus =
    field_const_standard_limbs_to_bignum_bigint
      (module Circuit)
      foreign_field_modulus
  in

  (* Get all limbs of negated foreign field modulus (coefficients) *)
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    (* Compute negated foreign field modulus f' = 2^t - f public parameter *)
    let neg_foreign_field_modulus =
      Bignum_bigint.(binary_modulus - foreign_field_modulus)
    in
    bignum_bigint_to_field_const_standard_limbs
      (module Circuit)
      neg_foreign_field_modulus
  in

  (* Compute witness values *)
  let ( remainder01
      , remainder2
      , quotient0
      , quotient1
      , quotient2
      , quotient_hi_bound
      , product1_lo
      , product1_hi_0
      , product1_hi_1
      , carry0
      , carry1_0
      , carry1_12
      , carry1_24
      , carry1_36
      , carry1_48
      , carry1_60
      , carry1_72
      , carry1_84
      , carry1_86
      , carry1_88
      , carry1_90 ) =
    exists (Typ.array ~length:21 Field.typ) ~compute:(fun () ->
        (* Compute quotient remainder and negative foreign field modulus *)
        let quotient, remainder =
          (* Bignum_bigint computations *)
          let left_input =
            Element.Standard.to_bignum_bigint_as_prover
              (module Circuit)
              left_input
          in
          let right_input =
            Element.Standard.to_bignum_bigint_as_prover
              (module Circuit)
              right_input
          in

          (* Compute quotient and remainder using foreign field modulus *)
          let quotient, remainder =
            Common.bignum_bigint_div_rem
              Bignum_bigint.(left_input * right_input)
              foreign_field_modulus
          in
          (quotient, remainder)
        in

        (* Compute the intermediate products *)
        let products =
          let quotient =
            bignum_bigint_to_field_const_standard_limbs
              (module Circuit)
              quotient
          in
          let product0, product1, product2 =
            compute_intermediate_products
              (module Circuit)
              left_input right_input quotient
              ( neg_foreign_field_modulus0
              , neg_foreign_field_modulus1
              , neg_foreign_field_modulus2 )
          in

          ( Common.field_to_bignum_bigint (module Circuit) product0
          , Common.field_to_bignum_bigint (module Circuit) product1
          , Common.field_to_bignum_bigint (module Circuit) product2 )
        in

        (* Compute witness variables *)
        let product1_lo, product1_hi_0, product1_hi_1, carry0, carry1 =
          compute_witness_variables
            (module Circuit)
            products
            (bignum_bigint_to_standard_limbs remainder)
        in

        (* Compute bounds for multi-range-checks on quotient and remainder *)
        let quotient_hi_bound =
          Common.bignum_bigint_to_field (module Circuit)
          @@ compute_high_bound quotient foreign_field_modulus
        in

        (* Compute the rest of the witness data *)
        let quotient0, quotient1, quotient2 =
          bignum_bigint_to_field_const_standard_limbs (module Circuit) quotient
        in
        let remainder01, remainder2 =
          bignum_bigint_to_field_const_compact_limbs (module Circuit) remainder
        in

        [| remainder01
         ; remainder2
         ; quotient0
         ; quotient1
         ; quotient2
         ; quotient_hi_bound
         ; product1_lo
         ; product1_hi_0
         ; product1_hi_1
         ; carry0
         ; of_bits carry1 0 12
         ; of_bits carry1 12 24
         ; of_bits carry1 24 36
         ; of_bits carry1 36 48
         ; of_bits carry1 48 60
         ; of_bits carry1 60 72
         ; of_bits carry1 72 84
         ; of_bits carry1 84 86
         ; of_bits carry1 86 88
         ; of_bits carry1 88 90
         ; of_bits carry1 90 91
        |] )
    |> tuple21_of_array
  in

  (* NOTE: high bound checks and multi range checks for left and right are
   *       the responsibility of caller and should be done somewhere else *)
  let left_input0, left_input1, left_input2 =
    Element.Standard.to_limbs left_input
  in
  let right_input0, right_input1, right_input2 =
    Element.Standard.to_limbs right_input
  in

  (* Create ForeignFieldMul gate *)
  with_label "foreign_field_mul" (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (ForeignFieldMul
                 { (* left input *)
                   left_input0
                 ; left_input1
                 ; left_input2
                 ; (* right input *) right_input0
                 ; right_input1
                 ; right_input2
                 ; (* remainder *) remainder01
                 ; remainder2
                 ; (* quotient *) quotient0
                 ; quotient1
                 ; quotient2
                 ; quotient_hi_bound
                 ; (* products *) product1_lo
                 ; product1_hi_0
                 ; product1_hi_1
                 ; (* carries *) carry0
                 ; carry1_0
                 ; carry1_12
                 ; carry1_24
                 ; carry1_36
                 ; carry1_48
                 ; carry1_60
                 ; carry1_72
                 ; carry1_84
                 ; carry1_86
                 ; carry1_88
                 ; carry1_90
                 ; (* Coefficients *) foreign_field_modulus2
                 ; neg_foreign_field_modulus0
                 ; neg_foreign_field_modulus1
                 ; neg_foreign_field_modulus2
                 } )
        } ) ;

  (*
   * Add external checks (and related)
   *)
  External_checks.append_multi_range_check external_checks
    (quotient0, quotient1, quotient2) ;

  External_checks.append_multi_range_check external_checks
    (quotient_hi_bound, product1_lo, product1_hi_0) ;

  (* Instead of appending external check for compact MRC for remainder,
   * this is added directly, so that the standard limbs
   * (remainder0, remainder1, remainder2) are copyable in witness cells *)
  let remainder0, remainder1 =
    Range_check.compact_multi (module Circuit) remainder01 remainder2
  in

  External_checks.append_bound_check external_checks ~do_multi_range_check:false
    (Element.Standard.of_limbs (remainder0, remainder1, remainder2)) ;

  Element.Standard.of_limbs (remainder0, remainder1, remainder2)

(* Gadget to constrain conversion of bytes array (output of Keccak gadget)
 * into foreign field element with standard limbs (input of ECDSA gadget).
 * Include the endianness of the bytes list.
 *)
let bytes_to_standard_element (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    ~(endian : Keccak.endianness) (bytestring : Circuit.Field.t list)
    (fmod : f standard_limbs) (fmod_bitlen : int) =
  let open Circuit in
  (* Make the input bytestring a big endian value *)
  let bytestring =
    match endian with Little -> List.rev bytestring | Big -> bytestring
  in

  (* Convert the bytestring into a bigint *)
  let bytestring = Array.of_list bytestring in

  (* C1: Check modulus_bit_length = # of bits you unpack
   * This is partly implicit in the circuit given the number of byte outputs of Keccak:
   * · input_bitlen < fmod_bitlen : OK
   * · input_bitlen = fmod_bitlen : OK
   * · input_bitlen > fmod_bitlen : CONSTRAIN
   * Check that the most significant byte of the input is less than 2^(fmod_bitlen % 8)
   *)
  let input_bitlen = Array.length bytestring * 8 in
  if input_bitlen > fmod_bitlen then
    (* For the most significant one, constrain that it is less bits than required *)
    Lookup.less_than_bits
      (module Circuit)
      ~bits:(fmod_bitlen % 8) bytestring.(0) ;
  (* C2: Constrain bytes into standard foreign field element limbs => foreign field element z *)
  let elem =
    Element.Standard.of_bignum_bigint (module Circuit)
    @@ Common.cvar_field_bytes_to_bignum_bigint_as_prover (module Circuit)
    @@ Array.to_list bytestring
  in
  (* C3: Reduce z modulo foreign_field_modulus
   *
   *   Constrain z' = z + 0 modulo foreign_field_modulus using foreign field addition gate
   *
   *   Note: this is sufficient because z cannot be double the size due to bit length constraint
   *)
  let zero = Element.Standard.of_limbs (Field.zero, Field.zero, Field.zero) in
  (* C4: Range check z' < f *)
  (* Altogether this is a call to Foreign_field.add in default mode *)
  let output = add (module Circuit) elem zero fmod in

  (* return z' *)
  output

(*********)
(* Tests *)
(*********)

let%test_unit "foreign_field arithmetics gadgets" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    (* Helper to test foreign_field_add gadget
     *   Inputs:
     *     - left_input
     *     - right_input
     *     - foreign_field_modulus
     * Checks with multi range checks the size of the inputs.
     *)
    let test_add ?cs (left_input : Bignum_bigint.t)
        (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
        =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let expected =
              Bignum_bigint.((left_input + right_input) % foreign_field_modulus)
            in
            let foreign_field_modulus =
              bignum_bigint_to_field_const_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let left_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
            in
            let right_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
            in
            (* Create the gadget *)
            let sum =
              add
                (module Runner.Impl)
                left_input right_input foreign_field_modulus
            in
            (* Result row *)
            result_row
              (module Runner.Impl)
              ~label:"foreign_field_add_test" sum None ;

            (* Check that the inputs were foreign field elements *)
            let external_checks = External_checks.create (module Runner.Impl) in
            External_checks.append_bound_check external_checks left_input ;
            External_checks.append_bound_check external_checks right_input ;

            (* Sanity tests *)
            assert (Mina_stdlib.List.Length.equal external_checks.bounds 2) ;
            assert (Mina_stdlib.List.Length.equal external_checks.canonicals 0) ;
            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 0) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                0 ) ;
            assert (Mina_stdlib.List.Length.equal external_checks.limb_ranges 0) ;

            (* Perform external checks *)
            constrain_external_checks
              (module Runner.Impl)
              external_checks foreign_field_modulus ;

            (* Another sanity check *)
            as_prover (fun () ->
                let expected =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    expected
                in
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected sum ) ) ;
            () )
      in
      cs
    in

    (* Helper to test foreign_field_mul gadget with external checks
     *   Inputs:
     *     - inputs
     *     - foreign_field_modulus
     *     - is_sub: list of operations to perform
     *)
    let test_add_chain ?cs (inputs : Bignum_bigint.t list)
        (operations : op_mode list) (foreign_field_modulus : Bignum_bigint.t) =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* compute result of the chain *)
            let n = List.length operations in
            let chain_result = [| List.nth_exn inputs 0 |] in
            for i = 0 to n - 1 do
              let operation = List.nth_exn operations i in
              let op_sign =
                match operation with
                | Add ->
                    Bignum_bigint.one
                | Sub ->
                    Bignum_bigint.of_int (-1)
              in
              let inp = List.nth_exn inputs (i + 1) in
              let sum =
                Bignum_bigint.(
                  (chain_result.(0) + (op_sign * inp)) % foreign_field_modulus)
              in
              chain_result.(0) <- sum ; ()
            done ;

            let inputs =
              List.map
                ~f:(fun x ->
                  Element.Standard.of_bignum_bigint (module Runner.Impl) x )
                inputs
            in
            let foreign_field_modulus =
              bignum_bigint_to_field_const_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in

            (* Create the gadget *)
            let sum =
              sum_chain
                (module Runner.Impl)
                inputs operations foreign_field_modulus
            in
            result_row
              (module Runner.Impl)
              ~label:"test_add_chain_result" sum None ;

            (* Check sum matches expected result *)
            as_prover (fun () ->
                let expected =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    chain_result.(0)
                in
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected sum ) ) ;
            () )
      in
      cs
    in

    (* Helper to test foreign_field_mul gadget
     *  Inputs:
     *     cs                    := optional constraint system to reuse
     *     left_input            := left multiplicand
     *     right_input           := right multiplicand
     *     foreign_field_modulus := foreign field modulus
     *)
    let test_mul ?cs (left_input : Bignum_bigint.t)
        (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
        =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let expected =
              Bignum_bigint.(left_input * right_input % foreign_field_modulus)
            in
            let foreign_field_modulus =
              bignum_bigint_to_field_const_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let left_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
            in
            let right_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness (unused in this simple test) *)
            let unused_external_checks =
              External_checks.create (module Runner.Impl)
            in

            (* Create the gadget *)
            let product =
              mul
                (module Runner.Impl)
                unused_external_checks left_input right_input
                foreign_field_modulus
            in

            (* Check product matches expected result *)
            as_prover (fun () ->
                let expected =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    expected
                in
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected product ) ) ;
            () )
      in

      cs
    in

    (* Helper to test foreign_field_mul gadget with external checks
     *   Inputs:
     *     cs                    := optional constraint system to reuse
     *     left_input            := left multiplicand
     *     right_input           := right multiplicand
     *     foreign_field_modulus := foreign field modulus
     *)
    let test_mul_full ?cs (left_input : Bignum_bigint.t)
        (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
        =
      (* Generate and verify first proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let expected =
              Bignum_bigint.(left_input * right_input % foreign_field_modulus)
            in
            let foreign_field_modulus =
              bignum_bigint_to_field_const_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let left_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
            in
            let right_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness *)
            let external_checks = External_checks.create (module Runner.Impl) in

            (* Create the foreign field mul gadget *)
            let product =
              mul
                (module Runner.Impl)
                external_checks left_input right_input foreign_field_modulus
            in

            (* Sanity check product matches expected result *)
            as_prover (fun () ->
                let expected =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    expected
                in
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected product ) ) ;

            (* Check left input *)
            External_checks.append_bound_check external_checks left_input ;
            External_checks.append_canonical_check external_checks left_input ;

            (* Check right input *)
            External_checks.append_bound_check external_checks right_input ;
            External_checks.append_canonical_check external_checks right_input ;

            (* Check result *)
            External_checks.append_bound_check external_checks product ;
            External_checks.append_canonical_check external_checks product ;

            (* Sanity checks *)
            assert (Mina_stdlib.List.Length.equal external_checks.bounds 4) ;
            assert (Mina_stdlib.List.Length.equal external_checks.canonicals 3) ;
            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 2) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                0 ) ;
            assert (Mina_stdlib.List.Length.equal external_checks.limb_ranges 0) ;

            (* Perform external checks *)
            constrain_external_checks
              (module Runner.Impl)
              external_checks foreign_field_modulus )
      in

      cs
    in

    (* Helper to test foreign field arithmetics together
     * It computes a * b + a - b
     *)
    let test_ff ?cs (left_input : Bignum_bigint.t)
        (right_input : Bignum_bigint.t) (foreign_field_modulus : Bignum_bigint.t)
        =
      (* Generate and verify proof *)
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            (* Prepare test inputs *)
            let expected_mul =
              Bignum_bigint.(left_input * right_input % foreign_field_modulus)
            in
            let expected_add =
              Bignum_bigint.(
                (expected_mul + left_input) % foreign_field_modulus)
            in
            let expected_sub =
              Bignum_bigint.(
                (expected_add - right_input) % foreign_field_modulus)
            in
            let foreign_field_modulus =
              bignum_bigint_to_field_const_standard_limbs
                (module Runner.Impl)
                foreign_field_modulus
            in
            let left_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) left_input
            in
            let right_input =
              Element.Standard.of_bignum_bigint (module Runner.Impl) right_input
            in

            (* Create external checks context for tracking extra constraints
               that are required for soundness *)
            let external_checks = External_checks.create (module Runner.Impl) in

            (* Multiply something *)
            let product =
              mul
                (module Runner.Impl)
                external_checks left_input right_input foreign_field_modulus
            in

            (* Add something *)
            let addition =
              add (module Runner.Impl) product left_input foreign_field_modulus
            in
            result_row
              (module Runner.Impl)
              ~label:"foreign_field_test" addition None ;

            (* Subtract something *)
            let subtraction =
              sub
                (module Runner.Impl)
                addition right_input foreign_field_modulus
            in
            result_row
              (module Runner.Impl)
              ~label:"foreign_field_test" subtraction None ;

            (* Sanity checks *)
            as_prover (fun () ->
                let expected_mul =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    expected_mul
                in
                let expected_add =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    expected_add
                in
                let expected_sub =
                  Element.Standard.of_bignum_bigint
                    (module Runner.Impl)
                    expected_sub
                in
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected_mul product ) ;
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected_add addition ) ;
                assert (
                  Element.Standard.equal_as_prover
                    (module Runner.Impl)
                    expected_sub subtraction ) ) ;

            (* Check left input *)
            External_checks.append_bound_check external_checks left_input ;
            External_checks.append_canonical_check external_checks left_input ;

            (* Check right input *)
            External_checks.append_bound_check external_checks right_input ;
            External_checks.append_canonical_check external_checks right_input ;

            (* Check product *)
            External_checks.append_bound_check external_checks product ;
            External_checks.append_canonical_check external_checks product ;

            (* Check addition *)
            External_checks.append_bound_check external_checks addition ;
            External_checks.append_canonical_check external_checks addition ;

            (* Check subtraction *)
            External_checks.append_bound_check external_checks subtraction ;
            External_checks.append_canonical_check external_checks subtraction ;

            (* More sanity checks *)
            assert (Mina_stdlib.List.Length.equal external_checks.bounds 6) ;
            assert (Mina_stdlib.List.Length.equal external_checks.canonicals 5) ;
            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 2) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                0 ) ;
            assert (Mina_stdlib.List.Length.equal external_checks.limb_ranges 0) ;

            (* Perform external checks *)
            constrain_external_checks
              (module Runner.Impl)
              external_checks foreign_field_modulus )
      in
      cs
    in

    (* Test constants *)
    let secp256k1_modulus =
      Common.bignum_bigint_of_hex
        "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"
    in
    let secp256k1_max = Bignum_bigint.(secp256k1_modulus - Bignum_bigint.one) in
    let secp256k1_sqrt = Common.bignum_bigint_sqrt secp256k1_max in
    let pallas_modulus =
      Common.bignum_bigint_of_hex
        "40000000000000000000000000000000224698fc094cf91b992d30ed00000001"
    in
    let pallas_max = Bignum_bigint.(pallas_modulus - Bignum_bigint.one) in
    let pallas_sqrt = Common.bignum_bigint_sqrt pallas_max in
    let vesta_modulus =
      Common.bignum_bigint_of_hex
        "40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001"
    in
    let vesta_max = Bignum_bigint.(vesta_modulus - Bignum_bigint.one) in

    (* Single foreign field addition tests *)
    let cs =
      test_add
        (Common.bignum_bigint_of_hex
           "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
        (Common.bignum_bigint_of_hex
           "80000000000000000000000000000000000000000000000000000000000000d0" )
        secp256k1_modulus
    in
    let _cs = test_add ~cs secp256k1_max secp256k1_max secp256k1_modulus in
    let _cs = test_add ~cs pallas_max pallas_max secp256k1_modulus in
    let _cs = test_add ~cs vesta_modulus pallas_modulus secp256k1_modulus in
    let cs = test_add Bignum_bigint.zero Bignum_bigint.zero secp256k1_modulus in
    let _cs =
      test_add ~cs Bignum_bigint.zero Bignum_bigint.zero secp256k1_modulus
    in
    let _cs =
      test_add ~cs
        (Common.bignum_bigint_of_hex
           "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
        (Common.bignum_bigint_of_hex
           "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
        secp256k1_modulus
    in

    (* Negative single addition tests *)
    assert (
      Common.is_error (fun () ->
          (* check that the inputs need to be smaller than the modulus *)
          let _cs =
            test_add ~cs secp256k1_modulus secp256k1_modulus secp256k1_modulus
          in
          () ) ) ;

    assert (
      Common.is_error (fun () ->
          (* check wrong cs fails *)
          let _cs =
            test_add ~cs secp256k1_modulus secp256k1_modulus pallas_modulus
          in
          () ) ) ;

    (* Chain tests *)
    let cs =
      test_add_chain
        [ pallas_max
        ; pallas_max
        ; Common.bignum_bigint_of_hex
            "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d"
        ; Common.bignum_bigint_of_hex
            "69cc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15"
        ; vesta_max
        ]
        [ Add; Sub; Sub; Add ] vesta_modulus
    in
    let _cs =
      test_add_chain ~cs
        [ vesta_max
        ; pallas_max
        ; Common.bignum_bigint_of_hex
            "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236"
        ; Common.bignum_bigint_of_hex
            "1342835834869e59534942304a03534963893045203528b523532232543"
        ; Common.bignum_bigint_of_hex
            "1f2d8f0d0cd52771bfb86ffdf651ddddbbddeeeebbbaaaaffccee20d"
        ]
        [ Add; Sub; Sub; Add ] vesta_modulus
    in

    (* Check that the number of inputs need to be coherent with number of operations *)
    assert (
      Common.is_error (fun () ->
          let _cs =
            test_add_chain ~cs [ pallas_max; pallas_max ] [ Add; Sub; Sub; Add ]
              secp256k1_modulus
          in
          () ) ) ;

    (* Foreign field multiplication tests *)
    (* zero_mul: 0 * 0 *)
    let cs = test_mul Bignum_bigint.zero Bignum_bigint.zero secp256k1_modulus in
    (* one_mul: max * 1 *)
    let _cs = test_mul ~cs secp256k1_max Bignum_bigint.one secp256k1_modulus in
    (* max_native_square: pallas_sqrt * pallas_sqrt *)
    let _cs = test_mul ~cs pallas_sqrt pallas_sqrt secp256k1_modulus in
    (* max_foreign_square: secp256k1_sqrt * secp256k1_sqrt *)
    let _cs = test_mul ~cs secp256k1_sqrt secp256k1_sqrt secp256k1_modulus in
    (* max_native_multiplicands: pallas_max * pallas_max *)
    let _cs = test_mul ~cs pallas_max pallas_max secp256k1_modulus in
    (* max_foreign_multiplicands: secp256k1_max * secp256k1_max *)
    let _cs = test_mul ~cs secp256k1_max secp256k1_max secp256k1_modulus in
    (* nonzero carry0 bits *)
    let _cs =
      test_mul ~cs
        (Common.bignum_bigint_of_hex
           "fbbbd91e03b48cebbac38855289060f8b29fa6ad3cffffffffffffffffffffff" )
        (Common.bignum_bigint_of_hex
           "d551c3d990f42b6d780275d9ca7e30e72941aa29dcffffffffffffffffffffff" )
        secp256k1_modulus
    in
    (* test random_multiplicands_valid *)
    let _cs =
      test_mul
        (Common.bignum_bigint_of_hex
           "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
        (Common.bignum_bigint_of_hex
           "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
        secp256k1_modulus
    in
    (* test smaller foreign field modulus *)
    let _cs =
      test_mul
        (Common.bignum_bigint_of_hex
           "5945fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c" )
        (Common.bignum_bigint_of_hex
           "747109f882b8e26947dfcd887273c0b0720618cb7f6d407c9ba74dbe0eda22f" )
        (Common.bignum_bigint_of_hex
           "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
    in
    (* vesta non-native on pallas native modulus *)
    let _cs =
      test_mul
        (Common.bignum_bigint_of_hex
           "69cc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15" )
        (Common.bignum_bigint_of_hex
           "1fffe27b14baa740db0c8bb6656de61d2871a64093908af6181f46351a1c1909" )
        vesta_modulus
    in

    (* Full test including all external checks *)
    let cs =
      test_mul_full
        (Common.bignum_bigint_of_hex "2")
        (Common.bignum_bigint_of_hex "3")
        secp256k1_modulus
    in

    let _cs =
      test_mul_full ~cs
        (Common.bignum_bigint_of_hex
           "1f2d8f0d0cd52771bfb86ffdf651b7907e2e0fa87f7c9c2a41b0918e2a7820d" )
        (Common.bignum_bigint_of_hex
           "b58c271d1f2b1c632a61a548872580228430495e9635842591d9118236bacfa2" )
        secp256k1_modulus
    in

    (* COMBINED TESTS *)
    let _cs =
      test_ff
        (Common.bignum_bigint_of_hex
           "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
        (Common.bignum_bigint_of_hex
           "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" )
        secp256k1_modulus
    in
    () )

let%test_unit "foreign_field equal_as_prover" =
  if tests_enabled then
    let open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in
    (* Check equal_as_prover *)
    let _cs, _proof_keypair, _proof =
      Runner.generate_and_verify_proof (fun () ->
          let open Runner.Impl in
          let x =
            Element.Standard.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "5925fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c"
          in
          let y =
            Element.Standard.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "69bc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15"
          in
          let z =
            Element.Standard.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "69bc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15"
          in
          as_prover (fun () ->
              assert (
                not (Element.Standard.equal_as_prover (module Runner.Impl) x y) ) ;
              assert (Element.Standard.equal_as_prover (module Runner.Impl) y z) ) ;

          let x =
            Element.Compact.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "5925fa400436f458cb9e994dcd315ded43e9b60eb68e2ae7b5cf1d07b48ca1c"
          in
          let y =
            Element.Compact.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "69bc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15"
          in
          let z =
            Element.Compact.of_bignum_bigint (module Runner.Impl)
            @@ Common.bignum_bigint_of_hex
                 "69bc93598e05239aa77b85d172a9785f6f0405af91d91094f693305da68bf15"
          in
          as_prover (fun () ->
              assert (
                not (Element.Compact.equal_as_prover (module Runner.Impl) x y) ) ;
              assert (Element.Compact.equal_as_prover (module Runner.Impl) y z) ) ;

          (* Pad with a "dummy" constraint b/c Kimchi requires at least 2 *)
          let fake =
            exists Field.typ ~compute:(fun () -> Field.Constant.zero)
          in
          Boolean.Assert.is_true (Field.equal fake Field.zero) ;
          () )
    in
    ()
