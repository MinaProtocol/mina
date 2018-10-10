(* diff_map.ml -- map to represent difference between locked, best tip *)

open Core

module type S = sig
  type key

  type value

  type ('key, 'value) t

  (* basic map ops *)

  val mem : (key, value) t -> key -> bool

  val find : (key, value) t -> key -> value option

  val set : (key, value) t -> key -> value -> (key, value) t

  (* group ops *)

  val identity : unit -> (key, value) t

  val add : (key, value) t -> (key, value) t -> (key, value) t Or_error.t

  val inverse : (key, value) t -> (key, value) t

  (* for testing *)

  val equal : (key, value) t -> (key, value) t -> bool
end

module Test = struct
  module Amount = Currency.Amount.Signed

  module User_amount_map :
    S with type key = string and type value = Amount.t =
  struct
    type key = string

    type value = Amount.t

    type ('key, 'value) t = ('key, 'value) Hashtbl.t

    let mem map key = Hashtbl.mem map key

    let find map key = Hashtbl.find map key

    let set map key value =
      (* NB: mutation *)
      Hashtbl.set map ~key ~data:value ;
      map

    (* make a fresh map each time; a particular instance may be mutated *)
    let identity () : (key, value) t = Hashtbl.create (module String)

    let add map1 map2 =
      let new_map = Hashtbl.copy map1 in
      let keys2 = Hashtbl.keys map2 in
      let sum_points valid key2 =
        if not valid then false (* don't do any work if error *)
        else
          let amount2 =
            match Hashtbl.find map2 key2 with
            | Some v -> v
            | None -> assert false
          in
          match Hashtbl.find new_map key2 with
          | Some amount1 -> (
            match Amount.add amount1 amount2 with
            | Some sum ->
                Hashtbl.set new_map ~key:key2 ~data:sum ;
                true
            | None -> false (* overflow *) )
          | None ->
            match Hashtbl.add new_map ~key:key2 ~data:amount2 with
            | `Ok -> true
            | `Duplicate -> assert false
      in
      if List.fold_left keys2 ~f:sum_points ~init:true then Ok new_map
      else
        Or_error.error_string
          "User_amount_map.add: overflow when adding map leaves"

    let inverse map =
      let new_map = identity () in
      Hashtbl.iteri map ~f:(fun ~key ~data:amount ->
          match Hashtbl.add new_map ~key ~data:(Amount.negate amount) with
          | `Ok -> ()
          | `Duplicate -> assert false ) ;
      new_map

    let equal map1 map2 =
      (* cheap check first *)
      if not (phys_equal (Hashtbl.length map1) (Hashtbl.length map2)) then
        false
      else
        let keys1 = Hashtbl.keys map1 in
        let keys2 = Hashtbl.keys map2 in
        let check map_a map_b accum key =
          accum (* invariant: key is in map_a *)
          && Hashtbl.mem map_b key
          && Hashtbl.find map_a key = Hashtbl.find map_b key
        in
        List.fold_left keys1 ~init:true ~f:(check map1 map2)
        && List.fold_left keys2 ~init:true ~f:(check map2 map1)
  end

  let make_test_map (entries: (string * int) list) =
    let amount_of_int n =
      if n >= 0 then Currency.Amount.of_int n |> Amount.of_unsigned
      else Currency.Amount.of_int (-n) |> Amount.of_unsigned |> Amount.negate
    in
    Core.List.fold
      ~init:(User_amount_map.identity ())
      ~f:(fun map (acct_key, amount) ->
        User_amount_map.set map acct_key (amount_of_int amount) )
      entries

  let test_map1 = make_test_map [("Alice", 42); ("Bob", 99); ("Charlie", 101)]

  let test_inverse_map1 =
    make_test_map [("Alice", -42); ("Bob", -99); ("Charlie", -101)]

  let test_map2 = make_test_map [("Alice", 33); ("Bob", 102)]

  let test_inverse_map2 = make_test_map [("Alice", -33); ("Bob", -102)]

  let test_sum_map =
    make_test_map [("Alice", 75); ("Bob", 201); ("Charlie", 101)]

  let%test "equal_maps_1" = User_amount_map.equal test_map1 test_map1

  let%test "equal_maps_2" = User_amount_map.equal test_map2 test_map2

  let%test "equal_maps_3" = not (User_amount_map.equal test_map1 test_map2)

  let%test "add_maps_1" =
    match User_amount_map.add test_map1 test_map2 with
    | Ok map -> User_amount_map.equal map test_sum_map
    | Error _s -> false

  (* overflow *)

  let%test "add_maps_2" =
    match User_amount_map.add test_map2 test_map1 with
    | Ok map -> User_amount_map.equal map test_sum_map
    | Error _s -> false

  (* overflow *)

  let%test "map_inverse_1" =
    User_amount_map.equal test_inverse_map1 (User_amount_map.inverse test_map1)

  let%test "map_inverse_2" =
    User_amount_map.equal test_inverse_map2 (User_amount_map.inverse test_map2)

  let%test "map_inverse_3" =
    User_amount_map.equal test_map1
      (User_amount_map.inverse (User_amount_map.inverse test_map1))

  let%test "map_inverse_4" =
    User_amount_map.equal test_map2
      (User_amount_map.inverse (User_amount_map.inverse test_map2))
end
