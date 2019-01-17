open Core
open Snarky

(* Welcome!

   Snarky is a library for constructing R1CS SNARKs.

   TODO: Explanation of R1CSs, how it makes addition and scalar mult 'free' but
   multiplication of variables costs 1.
*)
(* 0. First we instantiate Snarky with a 'backend' *)
module Impl = Snark.Make (Backends.Bn128.Default)
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
let assert_is_square_root_of_9 (x : Field.var) : (unit, _) Checked.t =
  let%bind x_squared = Field.Checked.mul x x in
  Field.Checked.Assert.equal x_squared
    (Field.Checked.constant (Field.of_int 9))

(* Exercise 1:
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

let assert_is_cube_root_of_1 (x : Field.var) = failwith "Exercise 1"

let cube_root_of_1 =
  let open Field in
  Infix.((of_int (-1) + sqrt (of_int (-3))) / of_int 2)

let exercise1 () =
  (* Before we generate a constraint system or a proof for our checked
     computation we must first specify the "data spec" of the input.

     This is actually an HList which we can represent in OCaml by overriding the
     list type constructors. We also need to make input a function over unit due
     to value restriction reasons.

     Here our function `assert_is_curbe_root_of_1` takes a single Field.var as
     input. The type of that var is `Field.typ`.
   *)
  let input () = Data_spec.[Field.typ] in
  (* Now we generate a keypair that we can use produce and verify proofs *)
  let keypair =
    generate_keypair ~exposing:(input ()) assert_is_cube_root_of_1
  in
  (* Now we prove: Here is an input to `assert_is_cube_root_of_1` such that the
     checked computation terminates without failing any assertions. In other
     words, there exists some cube_root_of_1.
   *)
  let proof =
    prove (Keypair.pk keypair) (input ()) () assert_is_cube_root_of_1
      cube_root_of_1
  in
  (* We can verify a proof as follows *)
  let is_valid = verify proof (Keypair.vk keypair) (input ()) cube_root_of_1 in
  printf !"is %{sexp:Field.t} a cube root of 1? %b\n%!" cube_root_of_1 is_valid

(* Exercise 1: Comment this out when you're ready to test it! *)
(* let () = exercise1 () *)

let exercise2 () =
  (* Now let's prove that there are two cube roots of 1. *)
  let distinct_cube_roots_of_1 x y =
    let%map () = assert_is_cube_root_of_1 x
    and () = assert_is_cube_root_of_1 y
    and () = Field.Checked.Assert.not_equal x y in
    ()
  in
  (* Exercise 2:
     Now you try: Creating a data spec, keypair, proof, and verifying that proof
     for `distinct_cube_roots_of_1`.
   *)
  let another_cube_root_of_1 = failwith "x^3 = 1, find x" in
  let input () = failwith "Exercise 2: Data_spec here" in
  let keypair = failwith "Exercise 2: Keypair here" in
  let proof = failwith "Exercise 2: Proof" in
  let is_valid = failwith "Exercise 2: Verify" in
  printf
    !"Are %{sexp:Field.t} and %{sexp:Field.t} two distinct cube roots of 1? %b\n\
      %!"
    cube_root_of_1 another_cube_root_of_1 is_valid

(* Exercise 2: Comment this out when you're ready to test it! *)
(* let () = exercise2 () *)

module Exercise3 = struct
  (* We can encode more richer data types in terms of the underlying fields. One
     example of this is a Boolean.

     A Boolean is just a Field element that is either zero or one. We can build
     all sorts of utility functions on 

     For example, `ifeqxy_x_else_z` checkes if x and y are equal and if so
     returns x. If not, we return z.

     This is also an example of a Checked computation that doesn't return unit!
   *)
  let ifeqxy_x_else_z x y z =
    let%bind b = Field.Checked.equal x y in
    Field.Checked.if_ b ~then_:x ~else_:z

  (* We can also define a matrix over some ring as follows *)
  module Matrix (R : sig
    type t [@@deriving sexp]

    val zero : t

    val mul : t -> t -> t

    val add : t -> t -> t
  end) =
  struct
    type t = R.t array array [@@deriving sexp]

    let rows t = Array.length t

    let row t i = t.(i)

    let col t i = Array.map t ~f:(fun xs -> xs.(i))

    let cols t = Array.length t.(0)

    let mul a b =
      (* n x m * m x p -> n x p *)
      assert (cols a = rows b) ;
      Array.init (rows a) ~f:(fun i ->
          Array.init (cols b) ~f:(fun j ->
              Array.fold2_exn (row a i) (col b j) ~init:R.zero
                ~f:(fun acc aik bkj -> R.add acc (R.mul aik bkj) ) ) )
  end

  (* A Field is a ring *)
  module Mat = Matrix (Field)

  (* We can multiply *)
  let a =
    Field.
      [|[|of_int 1; of_int 2; of_int 3|]; [|of_int 4; of_int 5; of_int 6|]|]

  let b =
    let open Field in
    [|[|of_int 1; of_int 2|]; [|of_int 3; of_int 4|]; [|of_int 5; of_int 6|]|]

  let () = printf !"Result %{sexp: Mat.t}\n%!" (Mat.mul a b)

  (* Exercise 3:
   * Write `assert_exists_mat_sqrt` that takes an x and a sqrt_x and asserts
   * that sqrt_x is a valid sqrt of x (with respect to matrix multiplication).
   * Note that this involves implementing matrix multiplication in terms of
   * checked computations. 
   *
   * Bonus: Try an adjust the Matrix definition above to functor over a monad,
   * make mul monadic. Then instantiate the Field version with the identity
   * monad, and the Field.Checked version with the Checked monad
   *)
  module Mat_checked = struct
    type t = Field.var array array

    (* Exercise 3: fill me out *)
    let mul : t -> t -> (t, _) Checked.t =
     fun a b -> failwith "Exercise3: Write mul"
  end

  let assert_exists_mat_sqrt x sqrt_x =
    failwith "Exercise 3: write a snark proof"

  (* Let's partially apply it to some arbitrary matrix that we can pretend we
     "don't know the sqrt of" so we can prove something interesting. In
     reality, since this is just a tutorial, we're going to hardcode a boring
     matrix (the square of [1; 2]; [4; 5] )
  *)
  let assert_exists_sqrt sqrt_x =
    let f x = Field.Checked.constant (Field.of_int x) in
    assert_exists_mat_sqrt [|[|f 9; f 12|]; [|f 24; f 33|]|] sqrt_x

  (* Now the data_spec is more interesting:
     First of all, SNARKs require fixed sized inputs, so we'll fix our proof to
     work over matrices of size exactly 2x2.
     Second, we're not just using a boring field, we have nested arrays. The
     `Typ` module has combinators for building up lists of typs and arrays of
     typs.
     There's also a `transport` where if you provide self-inverse `there` and
     `back` functions you can describe more complex types for the snark.

     Look at the available functions on `Typ` by using your editor's autocomplete
   *)
  let input () =
    let cols = Typ.array ~length:2 Field.typ in
    let matrix = Typ.array ~length:2 cols in
    Data_spec.[matrix]

  let keypair = generate_keypair ~exposing:(input ()) assert_exists_sqrt

  let mat_1245 = Field.[|[|of_int 1; of_int 2|]; [|of_int 4; of_int 5|]|]

  let proof =
    prove (Keypair.pk keypair) (input ()) () assert_exists_sqrt mat_1245

  let is_valid = verify proof (Keypair.vk keypair) (input ()) mat_1245

  let run () =
    printf "Is mat_1245 the sqrt of our 9;12 24;33 matrix: %b?" is_valid
end

(* Exercise 3: Comment this out when you're ready to test it! *)
(* let () = Exercise3.run () *)
(* TODO: provide-witness / request *)
(* TODO: To_bits of_bits *)
