open Core_kernel
open! Alcotest
open Dsu

(* Mock data module for testing *)
module MockData : Data with type t = int = struct
  type t = int
  let merge a b = a + b
end

(* Instantiate the DSU with int keys and mock data *)
module IntKey = Dsu (Int) (MockData)

(*
(* Test creating a new DSU *)
let test_create () =
  let dsu = IntKeyDsu.create () in
  (* Initially, the DSU should be empty, trying to get any element should return None *)
  Alcotest.(check (option int)) "empty DSU" (IntKeyDsu.get ~key:1 dsu) None

*)