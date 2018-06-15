open Core
open Snarky

(* Welcome!

   Snarky is a library for constructing R1CS SNARKs.

   TODO: Explanation of R1CSs, how it makes addition and scalar mult 'free' but
   multiplication of variables costs 1.
*)

(* 0. First we instantiate Snarky with a 'backend' *)
module Impl = Snark.Make(Backends.Bn128)
open Impl
open Let_syntax

(* 1. There is a monad called 'Checked'. It has an extra type parameter but let's
  ignore that for now *)

let _foo () : (unit, _) Checked.t = Checked.return ()

(* The point of this monad is to describe "checked computations"
   which are computations that may "request" values from their environment,
   and make assertions about values that arise in the computation.

   You "run" Checked.t's in two ways:
   1. To generate a constraint system for the SNARK
   2. To generate proofs. 

   We'll see exactly how this works later.

   First let's understand "field var"s which are the main primitive type we
   have access to in Checked.t's.
*)

(* A [Field.t] represents an element of the finite field of order [Field.size]
   It is a prime order field so you can think about it as "integers mod Field.size".
*)

let () =
  let x = Field.of_int 23 in
  let x_cubed = Field.mul x (Field.square x) in
  let z = Field.Infix.(x_cubed / x) in
  assert (Field.equal z (Field.square x))

(* Try seeing what operations there are in the [Field] module by using
   your editor's auto-completion feature
*)

(* Inside Checked.t's we work with "Field.var"s. These are sort of like
   Field.t's but we can make assertions about them.

   Field.Checked provides "Checked" versions of the usual field operations.
*)


(* [assert_equal : Field.var -> Field.var -> (unit, _) Checked.t] lets us
   make an assertion that two field elements are equal.

   Here we assert that [x] is a square root of 9.
*)
(* TODO: Have Field.Checked. *)
let assert_is_square_root_of_9 (x : Field.var) : (unit, _) Checked.t =
  let%bind x_squared = Checked.mul x x in (* TODO: Put this in Field.Checked *)
  assert_equal x_squared (Cvar.constant (Field.of_int 9)) (* TODO: Field.Checked.constant, Field.Checked.of_int *)

(* Exercise:
   Write a function
   [assert_is_cube_root_of_1 : Field.var -> (unit, _) Checked.t]
   that asserts its argument is a cube root of 1.

   Aside:
   In finite fields there may be either 1 or 3 cube roots of 1.
   This is because

   x^3 - 1 = (x - 1)(x^2 + x + 1)

   so if [x^2 + x + 1] has a root in the field, then we will get
   another cube root of 1. By quadratic formula,

   x^2 + x + 1 = 0 iff
   x = ( -1 +/- sqrt (1 - 4) ) / 2

   so if sqrt(1 - 4) = sqrt(-3) exists in the field then there will
   be two additional cube roots of 1.
*)

(* In this field, it happens to be the case that -3 is a square. *)
let () = assert (Field.is_square (Field.of_int (-3)))

(* TODO: pk -> proving_key *)
let assert_is_cube_root_of_1 (x : Field.var) = return ()

let input () = Data_spec.([ Field.typ ])

let keypair =
  generate_keypair ~exposing:(input ())
    assert_is_cube_root_of_1

let cube_root_of_1 =
  let open Field in
  let open Infix in
  (of_int (-1) + sqrt (of_int (-3))) / of_int 2

let proof =
  prove (Keypair.pk keypair) (input ()) ()
    assert_is_cube_root_of_1
    cube_root_of_1

let () =
  printf !"is %{sexp:Field.t} a cube root of 1? %b\n%!"
    cube_root_of_1
    (verify proof (Keypair.vk keypair) (input ()) cube_root_of_1)

(* Now let's prove that there are two cube roots of 1. *)
let distinct_cube_roots_of_1 x y =
  let%map () = assert_is_cube_root_of_1 x
  and () = assert_is_cube_root_of_1 y
  and () = Checked.Assert.not_equal x y (* TODO: Checked.Assert.not_equal? Field.Checked.Assert.not_equal, Field.Checked.Assert.equal *)
  in
  ()

(* TODO: put somewhere *)
let square_root x =
  let%bind y =
    provide_witness Field.typ As_prover.(map (read Field.typ x) ~f:Field.sqrt) (* TODO: explain *)
  in
  let%map () = assert_r1cs x x y in (* TODO: Explain... everything *)
  y

