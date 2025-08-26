open Core_kernel
open! Alcotest
open Dsu

(* Mock data module for testing *)
module MockData : Data with type t = int = struct
  type t = int
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
  let arr_size = QCheck.Gen.(int_range 50 60) in
  let arr = QCheck.Gen.(generate1 (array_size arr_size int)) in
  (* a ref to an array size int*)
  let arr_size = ref (Array.length arr) in
  Array.iter arr ~f:(fun x ->
      match IntKeyDsu.get ~key:x dsu with
      | Some _ ->
          (* in case qcheck generates repeats we don't want the test to fail *)
          arr_size := !arr_size - 1
      | None ->
          IntKeyDsu.add_exn ~key:x ~value:x dsu ) ;
  Alcotest.(check int)
    "verifying capacity is 64 i.e min capacity" (IntKeyDsu.capacity dsu) 64 ;
  Alcotest.(check int)
    (* we add 1 to account for the default 0 element used for dynamic deletions in the dsu *)
    "verifying occupancy is the size of the array additions" (!arr_size + 1)
    (IntKeyDsu.occupancy dsu) ;
  (* add 400 more items for resize *)
  (* generates on a normal distribution so there are low risk of repeats to skip allocation *)
  let arr = QCheck.Gen.(generate1 (array_size (int_range 400 401) int)) in
  Array.iter arr ~f:(fun x -> IntKeyDsu.add_exn ~key:x ~value:x dsu) ;
  Alcotest.(check int)
    "verifying capacity is 512 meaning there have been 3 re-allocations"
    (IntKeyDsu.capacity dsu) 512

let test_get_non_existent_element () =
  let dsu = IntKeyDsu.create () in
  Alcotest.(check (option int))
    "non-existent element" (IntKeyDsu.get ~key:1 dsu) None
  (* also verify the occupancy *) ;
  Alcotest.(check int) "occupancy" (IntKeyDsu.occupancy dsu) 1

let test_union_existing_with_non_existent_element () =
  let dsu = IntKeyDsu.create () in
  IntKeyDsu.add_exn ~key:1 ~value:1 dsu ;
  IntKeyDsu.union ~a:1 ~b:2 dsu ;
  Alcotest.(check (option int))
    "non-existent element" (IntKeyDsu.get ~key:2 dsu) None ;
  (* also test the occupancy, we have 2 to account for the 0 case *)
  Alcotest.(check int) "occupancy" (IntKeyDsu.occupancy dsu) 2 ;
  (* verify the size of the existing element *)
  let element_size = IntKeyDsu.get_size ~key:1 dsu in
  Alcotest.(check (option int)) "size" element_size (Some 1) ;
  Alcotest.(check (option int))
    "checking size of 2"
    (IntKeyDsu.get_size ~key:2 dsu)
    None

let test_union_non_existent_elements () =
  let dsu = IntKeyDsu.create () in
  IntKeyDsu.union ~a:1 ~b:2 dsu ;
  Alcotest.(check (option int))
    "non-existent element" (IntKeyDsu.get ~key:1 dsu) None ;
  Alcotest.(check (option int))
    "non-existent element" (IntKeyDsu.get ~key:2 dsu) None ;
  Alcotest.(check int) "occupancy" (IntKeyDsu.occupancy dsu) 1

let test_union_existing_elements () =
  let dsu = IntKeyDsu.create () in
  IntKeyDsu.add_exn ~key:1 ~value:1 dsu ;
  IntKeyDsu.add_exn ~key:2 ~value:2 dsu ;
  IntKeyDsu.add_exn ~key:3 ~value:3 dsu ;
  IntKeyDsu.union ~a:1 ~b:2 dsu ;
  Alcotest.(check (option int))
    "checking size of 1"
    (IntKeyDsu.get_size ~key:1 dsu)
    (Some 2) ;
  Alcotest.(check (option int))
    "checking size of 2"
    (IntKeyDsu.get_size ~key:2 dsu)
    (Some 0) ;
  IntKeyDsu.union ~a:2 ~b:3 dsu ;
  Alcotest.(check (option int))
    "existent element 1" (IntKeyDsu.get ~key:1 dsu) (Some 1) ;
  Alcotest.(check (option int))
    "existent element 2" (IntKeyDsu.get ~key:2 dsu) (Some 1) ;
  Alcotest.(check (option int))
    "existent element 3" (IntKeyDsu.get ~key:3 dsu) (Some 1) ;

  Alcotest.(check int) "occupancy" (IntKeyDsu.occupancy dsu) 4 ;
  (* verify the size of the existing elements *)
  let element_size = IntKeyDsu.get_size ~key:1 dsu in
  Alcotest.(check (option int)) "size 1" element_size (Some 3) ;
  let element_size = IntKeyDsu.get_size ~key:2 dsu in
  (* since 2 has a higher size than 3 we should merge 2 into 3 increasing the size to of 2 to 2 *)
  Alcotest.(check (option int)) "size 2" element_size (Some 0) ;
  let element_size = IntKeyDsu.get_size ~key:3 dsu in
  Alcotest.(check (option int)) "size 3" element_size (Some 0)

let test_remove () =
  let dsu = IntKeyDsu.create () in
  IntKeyDsu.add_exn ~key:1 ~value:1 dsu ;
  IntKeyDsu.add_exn ~key:2 ~value:2 dsu ;
  IntKeyDsu.add_exn ~key:3 ~value:3 dsu ;
  IntKeyDsu.union ~a:1 ~b:2 dsu ;
  IntKeyDsu.union ~a:2 ~b:3 dsu ;
  IntKeyDsu.remove ~key:2 dsu ;
  Alcotest.(check (option int))
    "removed element" (IntKeyDsu.get ~key:2 dsu) None ;
  Alcotest.(check (option int))
    "existent element 1" (IntKeyDsu.get ~key:1 dsu) None ;
  Alcotest.(check (option int))
    "existent element 3" (IntKeyDsu.get ~key:3 dsu) None ;
  (* no dynamic resizing so we do not remove the remaining element just yet *)
  Alcotest.(check int) "occupancy" (IntKeyDsu.occupancy dsu) 3

let test_deallocation () =
  let dsu = IntKeyDsu.create () in
  let arr_size = QCheck.Gen.(int_range 130 140) in
  let arr = QCheck.Gen.(generate1 (array_size arr_size int)) in
  let arr_size = Array.length arr in
  (* a ref to an array size int*)
  Alcotest.(check int)
    "verifying capacity is 64 i.e min capacity" (IntKeyDsu.capacity dsu) 64 ;
  Array.iter arr ~f:(fun x -> IntKeyDsu.add_exn ~key:x ~value:x dsu) ;
  Alcotest.(check int)
    (* we add 1 to account for the default 0 element used for dynamic deletions in the dsu *)
    "verifying occupancy is the size of the array additions" (arr_size + 1)
    (IntKeyDsu.occupancy dsu) ;

  Alcotest.(check int)
    "verifying capacity is 1024 meaning there have been 4 re-allocations"
    (IntKeyDsu.capacity dsu) 256 ;

  Array.iter arr ~f:(fun x -> IntKeyDsu.remove ~key:x dsu) ;
  Alcotest.(check int) "occupancy" (IntKeyDsu.occupancy dsu) 1 ;
  Alcotest.(check int) "capacity" (IntKeyDsu.capacity dsu) 64

let test_complicated_merge () =
  let keys =
    [ 1
    ; 2
    ; 3
    ; 4
    ; 5
    ; 6
    ; 7
    ; 8
    ; 9
    ; 10
    ; 11
    ; 12
    ; 13
    ; 14
    ; 15
    ; 16
    ; 17
    ; 18
    ; 19
    ; 20
    ; 21
    ; 22
    ; 23
    ; 24
    ; 25
    ; 26
    ; 27
    ; 28
    ; 29
    ; 30
    ; 31
    ; 32
    ; 33
    ; 34
    ; 35
    ; 36
    ; 37
    ; 38
    ; 39
    ; 40
    ; 41
    ; 42
    ; 43
    ; 44
    ; 45
    ; 46
    ; 47
    ; 48
    ; 49
    ; 50
    ; 51
    ; 52
    ; 53
    ; 54
    ; 55
    ; 56
    ; 57
    ; 58
    ; 59
    ; 60
    ; 61
    ; 62
    ; 63
    ; 64
    ; 65
    ; 66
    ; 67
    ; 68
    ; 69
    ; 70
    ; 71
    ; 72
    ; 73
    ; 74
    ; 75
    ; 76
    ; 77
    ; 78
    ; 79
    ; 80
    ; 81
    ; 82
    ; 83
    ; 84
    ; 85
    ; 86
    ; 87
    ; 88
    ; 89
    ; 90
    ; 91
    ; 92
    ; 93
    ; 94
    ; 95
    ; 96
    ; 97
    ; 98
    ; 99
    ; 100
    ]
  in
  let dsu = IntKeyDsu.create () in
  List.iter keys ~f:(fun x -> IntKeyDsu.add_exn ~key:x ~value:x dsu) ;
  List.iter (List.take keys 75) ~f:(fun x -> IntKeyDsu.union ~a:1 ~b:x dsu) ;
  (* checking capacity *)
  Alcotest.(check int) "checking the capacity" (IntKeyDsu.capacity dsu) 128 ;
  (* checking occupancy *)
  Alcotest.(check (option int))
    "checking size of 1"
    (IntKeyDsu.get_size ~key:1 dsu)
    (Some 75) ;
  Alcotest.(check int) "checking the occupancy" (IntKeyDsu.occupancy dsu) 101 ;
  IntKeyDsu.remove ~key:44 dsu ;
  Alcotest.(check (option int))
    "checking size of 1" (IntKeyDsu.get ~key:1 dsu) None ;
  Alcotest.(check int) "checking the occupancy" (IntKeyDsu.occupancy dsu) 26 ;
  Alcotest.(check int) "checking the capacity" (IntKeyDsu.capacity dsu) 64 ;
  List.iter (List.drop keys 75) ~f:(fun x ->
      Alcotest.(check (option int))
        "checking size of 1" (IntKeyDsu.get ~key:x dsu) (Some x) ) ;
  IntKeyDsu.union ~a:80 ~b:90 dsu ;
  IntKeyDsu.union ~a:90 ~b:100 dsu ;
  IntKeyDsu.union ~a:99 ~b:100 dsu ;
  Alcotest.(check (option int))
    "checking size of 99"
    (IntKeyDsu.get_size ~key:99 dsu)
    (Some 0) ;
  Alcotest.(check (option int))
    "checking size of 100"
    (IntKeyDsu.get_size ~key:100 dsu)
    (Some 0) ;
  Alcotest.(check (option int))
    "checking size of 80"
    (IntKeyDsu.get_size ~key:80 dsu)
    (Some 4) ;
  Alcotest.(check (option int))
    "checking the size of 90"
    (IntKeyDsu.get_size ~key:90 dsu)
    (Some 0) ;
  Alcotest.(check (option int))
    "finding the root of 99"
    (IntKeyDsu.get ~key:99 dsu)
    (Some 80)

(* Test suite *)
let tests =
  [ ("test_create", `Quick, test_create)
  ; ("test_add", `Quick, test_add)
  ; ("test_add_array", `Quick, test_add_array)
  ; ("test_reallocation", `Quick, test_reallocation)
  ; ("test_get_non_existent_element", `Quick, test_get_non_existent_element)
  ; ( "test_union_existing_with_non_existent_element"
    , `Quick
    , test_union_existing_with_non_existent_element )
  ; ( "test_union_non_existent_elements"
    , `Quick
    , test_union_non_existent_elements )
  ; ("test_union_existing_elements", `Quick, test_union_existing_elements)
  ; ("test_remove", `Quick, test_remove)
  ; ("test_deallocation", `Quick, test_deallocation)
  ; ("test_complicated_merge", `Quick, test_complicated_merge)
  ]

let () = run "dsu" [ ("dsu", tests) ]
