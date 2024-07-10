(* Copyright (c) Viable Systems and TezEdge Contributors
   SPDX-License-Identifier: MIT *)

(* Unknown/UnknownBlock are not defined on Rust side to test the failure case *)

type movement =
  | Step of int
  | Expand of (int * int)
  | RotateLeft
  | RotateRight
  | Unknown
  | UnkownBlock of int

type movement_polymorphic =
  [ `Step of int
  | `Expand of int * int
  | `RotateLeft
  | `RotateRight
  | `Unknown
  | `UnkownBlock of int ]

module Rust = struct
  external tests_teardown : unit -> unit = "ocaml_interop_teardown"

  external twice : int -> int = "rust_twice"

  external twice_boxed_i64 : int64 -> int64 = "rust_twice_boxed_i64"

  external twice_boxed_i32 : int32 -> int32 = "rust_twice_boxed_i32"

  external twice_boxed_float : float -> float = "rust_twice_boxed_float"

  external twice_unboxed_float : (float[@unboxed]) -> (float[@unboxed])
    = "" "rust_twice_unboxed_float"

  external add_unboxed_floats_noalloc : float -> float -> float
    = "" "rust_add_unboxed_floats_noalloc"
    [@@unboxed] [@@noalloc]

  external increment_bytes : bytes -> int -> bytes = "rust_increment_bytes"

  external increment_ints_list : int list -> int list
    = "rust_increment_ints_list"

  external make_tuple : string -> int -> string * int = "rust_make_tuple"

  external make_some : string -> string option = "rust_make_some"

  external make_ok : int -> (int, string) result = "rust_make_ok"

  external make_error : string -> (int, string) result = "rust_make_error"

  external sleep_releasing : int -> unit = "rust_sleep_releasing"

  external sleep : int -> unit = "rust_sleep"

  external string_of_movement : movement -> string = "rust_string_of_movement"

  external string_of_polymorphic_movement : movement_polymorphic -> string
    = "rust_string_of_polymorphic_movement"
end

let test_twice () = Alcotest.(check int) "Multiply by 2" 20 (Rust.twice 10)

let test_twice_boxed_i64 () =
  Alcotest.(check int64)
    "Multiply by 2 (boxed int64)" 20L (Rust.twice_boxed_i64 10L)

let test_twice_boxed_i32 () =
  Alcotest.(check int32)
    "Multiply by 2 (boxed int32)" 20l (Rust.twice_boxed_i32 10l)

let test_twice_boxed_float () =
  Alcotest.(check (float 0.0))
    "Multiply boxed float by 2" 20.0
    (Rust.twice_boxed_float 10.0)

let test_twice_unboxed_float () =
  Alcotest.(check (float 0.0))
    "Multiply unboxed float by 2" 20.0
    (Rust.twice_unboxed_float 10.0)

let test_add_unboxed_floats_noalloc () =
  Alcotest.(check (float 0.0))
    "Add two unboxed floats" 60.0
    (Rust.add_unboxed_floats_noalloc 10.0 50.0)

let test_increment_bytes () =
  let expected = Bytes.of_string "1111111111000000" in
  let result = Rust.increment_bytes (Bytes.of_string "0000000000000000") 10 in
  Alcotest.(check bytes) "Increment first 10 bytes" expected result

let test_increment_ints_list () =
  let expected = [ 1; 2; 3; 4; 5; 6; 7; 8; 9; 10 ] in
  let result = Rust.increment_ints_list [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9 ] in
  Alcotest.(check (list int)) "Increment ints in list" expected result

let test_make_tuple () =
  let expected = ("fst", 9) in
  let result = Rust.make_tuple "fst" 9 in
  Alcotest.(check (pair string int)) "Make a tuple" expected result

let test_make_some () =
  let expected = Some "some" in
  let result = Rust.make_some "some" in
  Alcotest.(check (option string)) "Make a Some(string)" expected result

let test_make_ok () =
  let expected = Ok 10 in
  let result = Rust.make_ok 10 in
  Alcotest.(check (result int string)) "Make an Ok(int)" expected result

let test_make_error () =
  let expected = Error "error" in
  let result = Rust.make_error "error" in
  Alcotest.(check (result int string)) "Make an Error(string)" expected result

let test_interpret_movement () =
  let expected =
    [ "RotateLeft"; "Step(10)"; "Error unpacking"; "Error unpacking" ]
  in
  let result =
    [
      Rust.string_of_movement RotateLeft;
      Rust.string_of_movement (Step 10);
      Rust.string_of_movement Unknown;
      Rust.string_of_movement (UnkownBlock 0);
    ]
  in
  Alcotest.(check (list string)) "Interpret a variant" expected result

let test_interpret_polymorphic_movement () =
  let expected =
    [ "`RotateLeft"; "`Step(10)"; "Error unpacking"; "Error unpacking" ]
  in
  let result =
    [
      Rust.string_of_polymorphic_movement `RotateLeft;
      Rust.string_of_polymorphic_movement (`Step 10);
      Rust.string_of_polymorphic_movement `Unknown;
      Rust.string_of_polymorphic_movement (`UnkownBlock 0);
    ]
  in
  Alcotest.(check (list string))
    "Interpret a polymorphic variant" expected result

(* Sleeps on the Rust thread releasing the OCaml runtime lock *)
let test_blocking_section () =
  let before = Unix.gettimeofday () in
  let p = Thread.create (fun () -> Rust.sleep_releasing 500) () in
  Thread.delay 0.01;
  let after = Unix.gettimeofday () in
  Thread.join p;
  let testable =
    if after -. before > 0.2 then
      Alcotest.fail "Blocking section releases the runtime lock"
    else Alcotest.pass
  in
  Alcotest.check testable "Blocking section releases the runtime lock" () ()

(* Sleeps on the Rust thread without releasing the OCaml runtime lock *)
let test_regular_section () =
  let before = Unix.gettimeofday () in
  let p = Thread.create (fun () -> Rust.sleep 500) () in
  Thread.delay 0.01;
  let after = Unix.gettimeofday () in
  Thread.join p;
  let testable =
    if after -. before < 0.5 then Alcotest.fail "Acquires the runtime lock"
    else Alcotest.pass
  in
  Alcotest.check testable "Acquires the runtime lock" () ()

let () =
  let open Alcotest in
  run "Tests"
    [
      ( "basic",
        [
          test_case "Rust.twice" `Quick test_twice;
          test_case "Rust.twice_boxed_i64" `Quick test_twice_boxed_i64;
          test_case "Rust.twice_boxed_i32" `Quick test_twice_boxed_i32;
          test_case "Rust.twice_boxed_float" `Quick test_twice_boxed_float;
          test_case "Rust.twice_unboxed_float" `Quick test_twice_unboxed_float;
          test_case "Rust.increment_bytes" `Quick test_increment_bytes;
          test_case "Rust.increment_ints_list" `Quick test_increment_ints_list;
          test_case "Rust.make_tuple" `Quick test_make_tuple;
          test_case "Rust.make_some" `Quick test_make_some;
          test_case "Rust.make_ok" `Quick test_make_ok;
          test_case "Rust.make_error" `Quick test_make_error;
          test_case "Rust.sleep_releasing" `Quick test_blocking_section;
          test_case "Rust.sleep" `Quick test_regular_section;
          test_case "Rust.string_of_movement" `Quick test_interpret_movement;
          test_case "Rust.string_of_polymorphic_movement" `Quick
            test_interpret_polymorphic_movement;
        ] );
    ];
  Rust.tests_teardown ()
