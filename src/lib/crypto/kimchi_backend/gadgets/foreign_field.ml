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

let tuple15_of_array array =
  match array with
  | [| a1; a2; a3; a4; a5; a6; a7; a8; a9; a10; a11; a12; a13; a14; a15 |] ->
      (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15)
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

(* Maximum foreign field modulus for multiplication m = sqrt(2^t * n), see RFC for more details
 *   For simplicity and efficiency we use the approximation m = floor(sqrt(2^t * n))
 *     * Distinct from this approximation is the maximum prime foreign field modulus
 *       for both Pallas and Vesta given our CRT scheme:
 *       926336713898529563388567880069503262826888842373627227613104999999999999999607 *)
let max_foreign_field_modulus (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) :
    Bignum_bigint.t =
  (* m = floor(sqrt(2^t * n)) *)
  let product =
    (* We need Zarith for sqrt *)
    Bignum_bigint.to_zarith_bigint
    @@ Bignum_bigint.(binary_modulus * Circuit.Field.size)
    (* Zarith.sqrt truncates (rounds down to int) ~ floor *)
  in
  Bignum_bigint.of_zarith_bigint @@ Z.sqrt product

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
    { mutable multi_ranges : 'field Cvar.t standard_limbs list
    ; mutable compact_multi_ranges : 'field Cvar.t compact_limbs list
    ; mutable bounds : 'field Cvar.t standard_limbs list
    }

  let create (type field)
      (module Circuit : Snark_intf.Run with type field = field) : field t =
    { multi_ranges = []; compact_multi_ranges = []; bounds = [] }

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

  (* Track a bound check (i.e. valid_element check) *)
  let append_bound_check (external_checks : 'field t)
      (x : 'field Cvar.t standard_limbs) =
    external_checks.bounds <- x :: external_checks.bounds
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

(* Represents two limbs as one single field element with twice as many bits *)
let as_prover_compact_limb (type f)
    (module Circuit : Snark_intf.Run with type field = f) (lo : f) (hi : f) : f
    =
  Circuit.Field.Constant.(lo + (hi * two_to_limb_field (module Circuit)))

(* FOREIGN FIELD ADDITION GADGET *)

(* Internal computation for foreign field addition *)
let sum_setup (type f) (module Circuit : Snark_intf.Run with type field = f)
    (left_input : f Element.Standard.t) (right_input : f Element.Standard.t)
    (operation : op_mode) (foreign_field_modulus : f standard_limbs) :
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
      (* Set up FFAdd gate *)
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

  (* Return the result *)
  (Element.Standard.of_limbs (result0, result1, result2), sign, field_overflow)

(* Gadget for creating an addition or subtraction result row (Zero gate with result) *)
let result_row (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(label = "result_zero_row") (result : f Element.Standard.t) =
  let open Circuit in
  let result0, result1, result2 = Element.Standard.to_limbs result in
  with_label label (fun () ->
      assert_
        { annotation = Some __LOC__
        ; basic =
            Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
              (Raw
                 { kind = Zero
                 ; values = [| result0; result1; result2 |]
                 ; coeffs = [||]
                 } )
        } )

(* Gadget to check the supplied value is a valid foreign field element for the
 * supplied foreign field modulus
 *
 *    This gadget checks in the circuit that a value is less than the foreign field modulus.
 *    Part of this involves computing a bound value that is both added to external_checks
 *    and also returned.  The caller may use either one, depending on the situation.
 *
 *    Inputs:
 *      external_checks       := Context to track required external checks
 *      value                 := the value to check
 *      foreign_field_modulus := the modulus of the foreign field
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Adds bound value to be multi-range-checked to external_checks
 *      Returns bound value
 *
 *    Effects to the circuit:
 *      - 1 FFAdd gate
 *      - 1 Zero gate
 *)
let valid_element (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f External_checks.t) (value : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let open Circuit in
  (* Compute the value for the right input of the addition as 2^264 *)
  let offset0 = Field.zero in
  let offset1 = Field.zero in
  let offset2 =
    exists Field.typ ~compute:(fun () -> two_to_limb_field (module Circuit))
  in
  (*let offset2 = Field.(mul one two_to_88) in*)
  (* Checks that these cvars have constant values are added as generics *)
  let offset = Element.Standard.of_limbs (offset0, offset1, offset2) in

  (* Check that the value fits in the foreign field *)
  as_prover (fun () ->
      assert (
        Element.Standard.fits_as_prover
          (module Circuit)
          value foreign_field_modulus ) ;
      () ) ;

  (* Create FFAdd gate to compute the bound value (i.e. part of valid_element check) *)
  let bound, sign, ovf =
    sum_setup (module Circuit) value offset Add foreign_field_modulus
  in
  (* Result row *)
  result_row (module Circuit) ~label:"final_add_zero_gate" bound ;

  (* Sanity check *)
  as_prover (fun () ->
      (* Check that the correct expected values were obtained *)
      let ovf = Common.cvar_field_to_field_as_prover (module Circuit) ovf in
      assert (Field.Constant.(equal sign one)) ;
      assert (Field.Constant.(equal ovf one)) ) ;

  (* Set up copy constraints with overflow with the overflow check*)
  Field.Assert.equal ovf Field.one ;

  (* Check that the highest limb of right input is 2^88*)
  let two_to_88 = two_to_limb_field (module Circuit) in
  Field.Assert.equal (Field.constant two_to_88) offset2 ;

  (* Add external check for multi range check *)
  External_checks.append_multi_range_check external_checks
  @@ Element.Standard.to_limbs bound ;

  (* Return the bound value *)
  bound

(* Gadget to constrain external checks using supplied modulus *)
let constrain_external_checks (type field)
    (module Circuit : Snark_intf.Run with type field = field)
    (external_checks : field External_checks.t) (modulus : field standard_limbs)
    =
  (* 1) Add gates for external bound additions.
   *    Note: internally this also adds multi-range-checks for the
   *    computed bound to the external_checks.multi-ranges, which
   *    are then constrainted in (2)
   *)
  List.iter external_checks.bounds ~f:(fun value ->
      let _bound =
        valid_element
          (module Circuit)
          external_checks
          (Element.Standard.of_limbs value)
          modulus
      in
      () ) ;

  (* 2) Add gates for external multi-range-checks *)
  List.iter external_checks.multi_ranges ~f:(fun multi_range ->
      let v0, v1, v2 = multi_range in
      Range_check.multi (module Circuit) v0 v1 v2 ;
      () ) ;

  (* 3) Add gates for external compact-multi-range-checks *)
  List.iter external_checks.compact_multi_ranges ~f:(fun compact_multi_range ->
      let v01, v2 = compact_multi_range in
      Range_check.compact_multi (module Circuit) v01 v2 ;
      () )

(* FOREIGN FIELD ADDITION CHAIN GADGET *)

(** Gadget for a chain of foreign field sums (additions or subtractions)
 *
 *    Inputs:
 *      inputs                := All the inputs to the chain of sums
 *      operations            := List of operation modes Add or Sub indicating whether th
 *                               corresponding addition is a subtraction
 *      foreign_field_modulus := The modulus of the foreign field (all the same)
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Returns the final result of the chain of sums
 *
 *    For n+1 inputs, the gadget creates n foreign field addition gates, followed by a final
 *    foreign field addition gate for the bound check (i.e. valid_element check). For this, a
 *    an additional multi range check must also be performed.
 *    By default, the range check takes place right after the final Raw row.
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
      sum_setup (module Circuit) left.(0) right op foreign_field_modulus
    in

    (* Update left input for next iteration *)
    left.(0) <- result ; ()
  done ;

  (* Add the final gate for the bound *)
  (* result + (2^264 - f) = bound *)
  let result = left.(0) in
  let unused_external_checks = External_checks.create (module Circuit) in
  let bound =
    valid_element
      (module Circuit)
      unused_external_checks result foreign_field_modulus
  in
  let bound0, bound1, bound2 = Element.Standard.to_limbs bound in

  (* Include Multi range check for the bound right after *)
  Range_check.multi (module Circuit) bound0 bound1 bound2 ;

  (* Return result *)
  result

(* FOREIGN FIELD ADDITION SINGLE GADGET *)

(* Definition of a gadget for a single foreign field addition
 *
 *    Inputs:
 *      full                  := Flag for whether to perform a full addition with valid_element check
 *                               on the result (default true) or just a single FFAdd row (false)
 *      left_input            := 3 limbs foreign field element
 *      right_input           := 3 limbs foreign field element
 *      foreign_field_modulus := The modulus of the foreign field
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Returns the result of the addition as a 3 limbs element
 *
 * In default mode:
 *     It adds a FFAdd gate,
 *     followed by a Zero gate,
 *     a FFAdd gate for the bound check,
 *     a Zero gate after this bound check,
 *     and a Multi Range Check gadget.
 *
 * In false mode:
 *     It adds a FFAdd gate.
 *)
let add (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(full = true) (left_input : f Element.Standard.t)
    (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  match full with
  | true ->
      sum_chain
        (module Circuit)
        [ left_input; right_input ]
        [ Add ] foreign_field_modulus
  | false ->
      let result, _sign, _ovf =
        sum_setup
          (module Circuit)
          left_input right_input Add foreign_field_modulus
      in
      result

(* Definition of a gadget for a single foreign field subtraction
 *
 *    Inputs:
 *      full                  := Flag for whether to perform a full subtraction with valid_element check
 *                               on the result (default true) or just a single FFAdd row (false)
 *      left_input            := 3 limbs foreign field element
 *      right_input           := 3 limbs foreign field element
 *      foreign_field_modulus := The modulus of the foreign field
 *
 *    Outputs:
 *      Inserts the gates (described below) into the circuit
 *      Returns the result of the addition as a 3 limbs element
 *
 * In default mode:
 *     It adds a FFAdd gate,
 *     followed by a Zero gate,
 *     a FFAdd gate for the bound check,
 *     a Zero gate after this bound check,
 *     and a Multi Range Check gadget.
 *
 * In false mode:
 *     It adds a FFAdd gate.
 *)
let sub (type f) (module Circuit : Snark_intf.Run with type field = f)
    ?(full = true) (left_input : f Element.Standard.t)
    (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  match full with
  | true ->
      sum_chain
        (module Circuit)
        [ left_input; right_input ]
        [ Sub ] foreign_field_modulus
  | false ->
      let result, _sign, _ovf =
        sum_setup
          (module Circuit)
          left_input right_input Sub foreign_field_modulus
      in
      result

(* FOREIGN FIELD MULTIPLICATION *)

(* Compute non-zero intermediate products
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

(* Compute intermediate sums
 *   For more details see the "Optimizations" Section of
 *   the [Foreign Field Multiplication RFC](https://o1-labs.github.io/proof-systems/rfcs/foreign_field_mul.html) *)
let compute_intermediate_sums (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (quotient : f standard_limbs) (neg_foreign_field_modulus : f standard_limbs)
    : f * f =
  let open Circuit in
  let quotient0, quotient1, quotient2 = quotient in
  let ( neg_foreign_field_modulus0
      , neg_foreign_field_modulus1
      , neg_foreign_field_modulus2 ) =
    neg_foreign_field_modulus
  in
  (* let q01 = q0 + 2^L * q1 *)
  let quotient01 =
    Field.Constant.(
      quotient0 + (two_to_limb_field (module Circuit) * quotient1))
  in

  (* f'01 = f'0 + 2^L * f'1 *)
  let neg_foreign_field_modulus01 =
    Field.Constant.(
      neg_foreign_field_modulus0
      + (two_to_limb_field (module Circuit) * neg_foreign_field_modulus1))
  in
  ( (* q'01 = q01 + f'01 *)
    Field.Constant.(quotient01 + neg_foreign_field_modulus01)
  , (* q'2 = q2 + f'2 *)
    Field.Constant.(quotient2 + neg_foreign_field_modulus2) )

(* Compute witness variables related for foreign field multplication *)
let compute_witness_variables (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (products : Bignum_bigint.t standard_limbs)
    (remainder : Bignum_bigint.t standard_limbs) : f * f * f * f * f * f =
  let products0, products1, products2 = products in
  let remainder0, remainder1, remainder2 = remainder in

  (* C1-C2: Compute components of product1 *)
  let product1_hi, product1_lo =
    Common.(bignum_bigint_div_rem products1 two_to_limb)
  in
  let product1_hi_1, product1_hi_0 =
    Common.(bignum_bigint_div_rem product1_hi two_to_limb)
  in

  (* C3-C5: Compute v0 = the top 2 bits of (p0 + 2^L * p10 - r0 - 2^L * r1) / 2^2L
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

  (* C6-C7: Compute v1 = the top L + 3 bits (p2 + p11 + v0 - r2) / 2^L
   *   N.b. Same as above, to avoid an underflow error, the equation must
   *        sum the intermediate product terms before subtracting the remainder. *)
  let carry1 =
    Bignum_bigint.(
      (products2 + product1_hi + carry0 - remainder2) / Common.two_to_limb)
  in
  (* Compute v10 and v11 *)
  let carry1_hi, carry1_lo =
    Common.(bignum_bigint_div_rem carry1 two_to_limb)
  in

  ( Common.bignum_bigint_to_field (module Circuit) product1_lo
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_0
  , Common.bignum_bigint_to_field (module Circuit) product1_hi_1
  , Common.bignum_bigint_to_field (module Circuit) carry0
  , Common.bignum_bigint_to_field (module Circuit) carry1_lo
  , Common.bignum_bigint_to_field (module Circuit) carry1_hi )

(* Perform integer bound addition computation x' = x + f' *)
let compute_bound (x : Bignum_bigint.t)
    (neg_foreign_field_modulus : Bignum_bigint.t) : Bignum_bigint.t =
  let x_bound = Bignum_bigint.(x + neg_foreign_field_modulus) in
  assert (Bignum_bigint.(x_bound < binary_modulus)) ;
  x_bound

(* Compute bound witness carry bit *)
let compute_bound_witness_carry (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (sums : Bignum_bigint.t compact_limbs)
    (bound : Bignum_bigint.t compact_limbs) : f =
  let sums01, _sums2 = sums in
  let bound01, _bound2 = bound in

  (* C9: witness data is created by externally by called and multi-range-check gate *)

  (* C10-C11: Compute q'_carry01 = (s01 - q'01)/2^2L *)
  let quotient_bound_carry, _ =
    Common.bignum_bigint_div_rem Bignum_bigint.(sums01 - bound01) two_to_2limb
  in
  Common.bignum_bigint_to_field (module Circuit) quotient_bound_carry

(* Foreign field multiplication gadget definition *)
let mul (type f) (module Circuit : Snark_intf.Run with type field = f)
    (external_checks : f External_checks.t) ?(bound_check_result = true)
    (left_input : f Element.Standard.t) (right_input : f Element.Standard.t)
    (foreign_field_modulus : f standard_limbs) : f Element.Standard.t =
  let open Circuit in
  (* Check foreign field modulus < max allowed *)
  check_modulus (module Circuit) foreign_field_modulus ;

  (* Compute gate coefficients
   *   This happens when circuit is created / not part of witness (e.g. exists, As_prover code)
   *)
  let foreign_field_modulus0, foreign_field_modulus1, foreign_field_modulus2 =
    foreign_field_modulus
  in
  let ( neg_foreign_field_modulus
      , ( neg_foreign_field_modulus0
        , neg_foreign_field_modulus1
        , neg_foreign_field_modulus2 ) ) =
    let foreign_field_modulus =
      field_const_standard_limbs_to_bignum_bigint
        (module Circuit)
        foreign_field_modulus
    in
    (* Compute negated foreign field modulus f' = 2^t - f public parameter *)
    let neg_foreign_field_modulus =
      Bignum_bigint.(binary_modulus - foreign_field_modulus)
    in
    ( neg_foreign_field_modulus
    , bignum_bigint_to_field_const_standard_limbs
        (module Circuit)
        neg_foreign_field_modulus )
  in

  (* Compute witness values *)
  let ( carry1_lo
      , carry1_hi
      , product1_hi_1
      , carry0
      , quotient0
      , quotient1
      , quotient2
      , quotient_bound_carry
      , remainder0
      , remainder1
      , remainder2
      , quotient_bound01
      , quotient_bound2
      , product1_lo
      , product1_hi_0 ) =
    exists (Typ.array ~length:15 Field.typ) ~compute:(fun () ->
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
          let foreign_field_modulus =
            field_const_standard_limbs_to_bignum_bigint
              (module Circuit)
              foreign_field_modulus
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
          let neg_foreign_field_modulus =
            bignum_bigint_to_field_const_standard_limbs
              (module Circuit)
              neg_foreign_field_modulus
          in
          let product0, product1, product2 =
            compute_intermediate_products
              (module Circuit)
              left_input right_input quotient neg_foreign_field_modulus
          in

          ( Common.field_to_bignum_bigint (module Circuit) product0
          , Common.field_to_bignum_bigint (module Circuit) product1
          , Common.field_to_bignum_bigint (module Circuit) product2 )
        in

        (* Compute the intermediate sums *)
        let sums =
          let quotient =
            bignum_bigint_to_field_const_standard_limbs
              (module Circuit)
              quotient
          in
          let neg_foreign_field_modulus =
            bignum_bigint_to_field_const_standard_limbs
              (module Circuit)
              neg_foreign_field_modulus
          in
          let sum01, sum2 =
            compute_intermediate_sums
              (module Circuit)
              quotient neg_foreign_field_modulus
          in
          ( Common.field_to_bignum_bigint (module Circuit) sum01
          , Common.field_to_bignum_bigint (module Circuit) sum2 )
        in

        (* Compute witness variables *)
        let ( product1_lo
            , product1_hi_0
            , product1_hi_1
            , carry0
            , carry1_lo
            , carry1_hi ) =
          compute_witness_variables
            (module Circuit)
            products
            (bignum_bigint_to_standard_limbs remainder)
        in

        (* Compute bounds for multi-range-checks on quotient and remainder *)
        let quotient_bound = compute_bound quotient neg_foreign_field_modulus in

        (* Compute quotient bound addition witness variables *)
        let quotient_bound_carry =
          compute_bound_witness_carry
            (module Circuit)
            sums
            (bignum_bigint_to_compact_limbs quotient_bound)
        in

        (* Compute the rest of the witness data *)
        let quotient0, quotient1, quotient2 =
          bignum_bigint_to_field_const_standard_limbs (module Circuit) quotient
        in
        let remainder0, remainder1, remainder2 =
          bignum_bigint_to_field_const_standard_limbs (module Circuit) remainder
        in
        let quotient_bound01, quotient_bound2 =
          bignum_bigint_to_field_const_compact_limbs
            (module Circuit)
            quotient_bound
        in

        [| carry1_lo
         ; carry1_hi
         ; product1_hi_1
         ; carry0
         ; quotient0
         ; quotient1
         ; quotient2
         ; quotient_bound_carry
         ; remainder0
         ; remainder1
         ; remainder2
         ; quotient_bound01
         ; quotient_bound2
         ; product1_lo
         ; product1_hi_0
        |] )
    |> tuple15_of_array
  in

  (* Add external checks *)
  External_checks.append_multi_range_check external_checks
    (carry1_lo, product1_lo, product1_hi_0) ;
  External_checks.append_compact_multi_range_check external_checks
    (quotient_bound01, quotient_bound2) ;
  if bound_check_result then
    External_checks.append_bound_check external_checks
      (remainder0, remainder1, remainder2) ;

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
                 { (* Current row *) left_input0
                 ; left_input1
                 ; left_input2
                 ; right_input0
                 ; right_input1
                 ; right_input2
                 ; carry1_lo
                 ; carry1_hi
                 ; carry0
                 ; quotient0
                 ; quotient1
                 ; quotient2
                 ; quotient_bound_carry
                 ; product1_hi_1
                 ; (* Next row *) remainder0
                 ; remainder1
                 ; remainder2
                 ; quotient_bound01
                 ; quotient_bound2
                 ; product1_lo
                 ; product1_hi_0
                 ; (* Coefficients *) foreign_field_modulus0
                 ; foreign_field_modulus1
                 ; foreign_field_modulus2
                 ; neg_foreign_field_modulus0
                 ; neg_foreign_field_modulus1
                 ; neg_foreign_field_modulus2
                 } )
        } ) ;
  Element.Standard.of_limbs (remainder0, remainder1, remainder2)

(* Gadget to constrain conversion of bytes array (output of Keccak gadget)
   into foreign field element with standard limbs (input of ECDSA gadget).
   Assumes bytes array is given in big endian. *)
let bytes_to_standard_element (type f)
    (module Circuit : Snark_intf.Run with type field = f)
    (bytestring : Circuit.Field.t array) (fmod : f standard_limbs)
    (fmod_bitlen : int) =
  let open Circuit in
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
            (* Create external checks context for tracking extra constraints *)
            let external_checks = External_checks.create (module Runner.Impl) in
            (* Check that the inputs were foreign field elements*)
            let _out =
              valid_element
                (module Runner.Impl)
                external_checks left_input foreign_field_modulus
            in
            let _out =
              valid_element
                (module Runner.Impl)
                external_checks right_input foreign_field_modulus
            in

            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 2) ;
            List.iter external_checks.multi_ranges ~f:(fun multi_range ->
                let v0, v1, v2 = multi_range in
                Range_check.multi (module Runner.Impl) v0 v1 v2 ;
                () ) ;

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

            (* External checks for this test (example, circuit designer has complete flexibility about organization)
               *   Layout
               *       0) ForeignFieldMul
               *       1) Zero
               *       2) ForeignFieldAdd           (result bound addition)
               *       3) Zero                      (result bound addition)
               *       4) ForeignFieldAdd           (left bound addition)
               *       5) Zero                      (left bound addition)
               *       6) ForeignFieldAdd           (right bound addition)
               *       7) Zero                      (right bound addition)
               *    8-11) multi-range-check         (right bound)
               *   12-15) multi-range-check         (left bound)
               *   16-19) multi-range-check         (result bound)
               *   20-23) multi-range-check         (product1_lo, product1_hi_0, carry1_lo)
               *   24-27) compact-multi-range-check (quotient)
            *)

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

            (* Add multi-range-check left input *)
            External_checks.append_bound_check external_checks
            @@ Element.Standard.to_limbs left_input ;

            (* Add multi-range-check right input *)
            External_checks.append_bound_check external_checks
            @@ Element.Standard.to_limbs right_input ;

            (*
             * Perform external checks
             *)
            assert (Mina_stdlib.List.Length.equal external_checks.bounds 3) ;
            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 1) ;
            assert (
              Mina_stdlib.List.Length.equal external_checks.compact_multi_ranges
                1 ) ;

            (* Add gates for bound checks, multi-range-checks and compact-multi-range-checks *)
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
            let unused_external_checks =
              External_checks.create (module Runner.Impl)
            in

            let product =
              mul
                (module Runner.Impl)
                unused_external_checks left_input right_input
                foreign_field_modulus
            in

            let addition =
              add (module Runner.Impl) product left_input foreign_field_modulus
            in
            let subtraction =
              sub
                (module Runner.Impl)
                addition right_input foreign_field_modulus
            in
            let external_checks = External_checks.create (module Runner.Impl) in

            (* Check product matches expected result *)
            (* Check that the inputs were foreign field elements*)
            let _out =
              valid_element
                (module Runner.Impl)
                external_checks left_input foreign_field_modulus
            in
            let _out =
              valid_element
                (module Runner.Impl)
                external_checks right_input foreign_field_modulus
            in

            assert (Mina_stdlib.List.Length.equal external_checks.multi_ranges 2) ;
            List.iter external_checks.multi_ranges ~f:(fun multi_range ->
                let v0, v1, v2 = multi_range in
                Range_check.multi (module Runner.Impl) v0 v1 v2 ;
                () ) ;

            (* Check product matches expected result *)
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
                    expected_sub subtraction ) ) )
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

    (* FFAdd TESTS *)
    (* Single tests *)
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

    (* FFMul TESTS*)

    (* Positive tests *)
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
    (* test nonzero carry10 *)
    let _cs =
      test_mul
        (Common.bignum_bigint_of_hex
           "4000000000000000000000000000000000000000000000000000000000000000" )
        (Common.bignum_bigint_of_hex
           "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0" )
        Bignum_bigint.(pow (of_int 2) (of_int 259))
    in
    (* test nonzero carry1_hi *)
    let _cs =
      test_mul
        (Common.bignum_bigint_of_hex
           "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" )
        (Common.bignum_bigint_of_hex
           "8000000000000000000000000000000000000000000000000000000000000000d0" )
        Bignum_bigint.(pow (of_int 2) (of_int 259) - one)
    in
    (* test nonzero_second_bit_carry1_hi *)
    let _cs =
      test_mul ~cs
        (Common.bignum_bigint_of_hex
           "ffffffffffffffffffffffffffffffffffffffffffffffff8a9dec7cfd1acdeb" )
        (Common.bignum_bigint_of_hex
           "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e" )
        secp256k1_modulus
    in
    (* test random_multiplicands_carry1_lo *)
    let _cs =
      test_mul ~cs
        (Common.bignum_bigint_of_hex
           "ffd913aa9e17a63c7a0ff2354218037aafcd6ecaa67f56af1de882594a434dd3" )
        (Common.bignum_bigint_of_hex
           "7d313d6b42719a39acea5f51de9d50cd6a4ec7147c003557e114289e9d57dffc" )
        secp256k1_modulus
    in
    (* test random_multiplicands_valid *)
    let _cs =
      test_mul ~cs
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
    () ) ;
  ()

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
