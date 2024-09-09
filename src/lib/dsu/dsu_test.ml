open Core_kernel
open! Alcotest
open Dsu

(* Mock data module for testing *)
module MockData : Data with type t = int = struct
  type t = int

  let merge a b = a + b
end

(* Instantiate the DSU with int keys and mock data *)
module IntKeyDsu = Dsu (Int) (MockData)

(* Test creating a new DSU *)
let test_create () =
  let dsu = IntKeyDsu.create () in
  Alcotest.(check (option int)) "empty DSU" (IntKeyDsu.get ~key:1 dsu) None

(* Test adding a single element to the dsu *)
let test_add () =
  let dsu = IntKeyDsu.create () in
  IntKeyDsu.add_exn ~key:1 ~value:1 dsu ;
  Alcotest.(check (option int))
    "added element" (IntKeyDsu.get ~key:1 dsu) (Some 1)

(* Test adding an array of arbitrary elements *)
let test_add_array () =
  let dsu = IntKeyDsu.create () in
  (* generate a qcheck array of ints *)
  let arr = QCheck.Gen.(generate1 (array_size (int_range 100 200) int)) in
  (* log the arrays size *)
  Printf.printf "Array size: %d\n" (Array.length arr) ;

  (* add each element to the dsu *)
  Array.iter arr ~f:(fun x -> IntKeyDsu.add_exn ~key:x ~value:x dsu) ;
  Array.iter arr ~f:(fun x ->
      Alcotest.(check (option int))
        "added element" (IntKeyDsu.get ~key:x dsu) (Some x) )

let test_reallocation () = 
  let dsu = IntKeyDsu.create () in
  let arr_size = QCheck.Gen.(int_range 10 15) in
  let arr = QCheck.Gen.(generate1 (array_size arr_size int)) in
  Array.iter arr ~f:(fun x -> IntKeyDsu.add_exn ~key:x ~value:x dsu) ;
  let arr_size = Array.length arr in
    Alcotest.(check (int))
        "verifying length is above min capacity" 
        (IntKeyDsu.capacity dsu) (64);
    Alcotest.(check (int))
        "verifying length is above min capacity" 
        (IntKeyDsu.capacity dsu) arr_size



(* alcotest harness *)
let tests =
  [ ("test_create", `Quick, test_create)
  ; ("test_add", `Quick, test_add)
  ; ("test_add_array", `Quick, test_add_array)
  ; ("test_reallocation", `Quick, test_reallocation)
  ]

let () = run "dsu" [ ("dsu", tests) ]
