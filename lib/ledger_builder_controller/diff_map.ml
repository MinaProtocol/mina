(* diff_map.ml -- map to represent difference between locked, best tip *)

module type MapWithGroupOpsS = sig
  type key

  type value

  type ('key, 'value) t

  (* basic map ops *)

  val mem : (key, value) t -> key -> bool

  val find : (key, value) t -> key -> value option

  val set : (key, value) t -> key -> value -> (key, value) t

  (* group ops *)

  val identity : unit -> (key, value) t

  val add : (key, value) t -> (key, value) t -> (key, value) t

  val inverse : (key, value) t -> (key, value) t

  (* for testing *)

  val equal : (key, value) t -> (key, value) t -> bool
end

module Test = struct
  module Amount = Currency.Amount

  module UserAmountMap :
    MapWithGroupOpsS with type key = string and type value = Amount.t * bool =
  struct
    type key = string

    type value = Amount.t * bool

    (* flag, true iff amount is negative *)

    type ('key, 'value) t = ('key, 'value) Hashtbl.t

    let mem map key = Hashtbl.mem map key

    let find map key = Hashtbl.find_opt map key

    let set map key value =
      (* NB: mutation *)
      Hashtbl.replace map key value ;
      map

    (* make a fresh map each time; a particular instance may be mutated *)
    let identity () = Hashtbl.create 17

    let add_amounts (amount1, negative1) (amount2, negative2) =
      match (negative1, negative2) with
      | b1, b2 when b1 = b2 -> (
        match Amount.add amount1 amount2 with
        | Some sum -> (sum, negative1)
        | None -> assert false )
      | b1, b2 ->
          let cmp = Amount.compare amount1 amount2 in
          if cmp < 0 then
            let diff =
              match Amount.sub amount2 amount1 with
              | Some v -> v
              | None -> assert false
            in
            (diff, b2)
          else if cmp > 0 then
            let diff =
              match Amount.sub amount1 amount2 with
              | Some v -> v
              | None -> assert false
            in
            (diff, b1)
          else (Amount.zero, false)

    (* arbitrarily choose flag *)

    let%test "add_amounts1" =
      let amount1 = (Amount.of_int 42, true) in
      let amount2 = (Amount.of_int 42, false) in
      add_amounts amount1 amount2 = (Amount.zero, false)

    let%test "add_amounts2" =
      let amount1 = (Amount.of_int 42, false) in
      let amount2 = (Amount.of_int 42, true) in
      add_amounts amount1 amount2 = (Amount.zero, false)

    let%test "add_amounts3" =
      let amount1 = (Amount.of_int 42, true) in
      let amount2 = (Amount.of_int 55, true) in
      add_amounts amount1 amount2 = (Amount.of_int 97, true)

    let%test "add_amounts4" =
      let amount1 = (Amount.of_int 42, false) in
      let amount2 = (Amount.of_int 55, false) in
      add_amounts amount1 amount2 = (Amount.of_int 97, false)

    let%test "add_amounts5" =
      let amount1 = (Amount.of_int 42, true) in
      let amount2 = (Amount.of_int 55, false) in
      add_amounts amount1 amount2 = (Amount.of_int 13, false)

    let%test "add_amounts6" =
      let amount1 = (Amount.of_int 42, false) in
      let amount2 = (Amount.of_int 55, true) in
      add_amounts amount1 amount2 = (Amount.of_int 13, true)

    let%test "add_amounts7" =
      let amount1 = (Amount.of_int 55, false) in
      let amount2 = (Amount.of_int 42, true) in
      add_amounts amount1 amount2 = (Amount.of_int 13, false)

    let%test "add_amounts8" =
      let amount1 = (Amount.of_int 55, true) in
      let amount2 = (Amount.of_int 42, false) in
      add_amounts amount1 amount2 = (Amount.of_int 13, true)

    let add map1 map2 =
      let new_map = Hashtbl.copy map1 in
      let keys2 = Hashtbl.to_seq_keys map2 in
      let sum_points key2 =
        let amount2 =
          match Hashtbl.find_opt map2 key2 with
          | Some (v, b) -> (v, b)
          | None -> assert false
        in
        match Hashtbl.find_opt new_map key2 with
        | Some amount1 ->
            let sum = add_amounts amount1 amount2 in
            Hashtbl.replace new_map key2 sum
        | None -> Hashtbl.add new_map key2 amount2
      in
      Seq.iter sum_points keys2 ; new_map

    let inverse map =
      let new_map = identity () in
      Hashtbl.iter
        (fun key (amount, negative) ->
          Hashtbl.add new_map key (amount, not negative) )
        map ;
      new_map

    let equal map1 map2 =
      (* cheap check first *)
      if Hashtbl.length map1 != Hashtbl.length map2 then false
      else
        let keys1 = Hashtbl.to_seq_keys map1 in
        let keys2 = Hashtbl.to_seq_keys map2 in
        let check map_a map_b accum key =
          accum (* invariant: key is in mapa *)
          && Hashtbl.mem map_b key
          && Hashtbl.find_opt map_a key = Hashtbl.find_opt map_b key
        in
        Seq.fold_left (check map1 map2) true keys1
        && Seq.fold_left (check map2 map1) true keys2
  end

  let make_test_map (entries: (string * int) list) =
    Core.List.fold
      ~init:(UserAmountMap.identity ())
      ~f:(fun map (acct_key, amount) ->
        let amount_t, negative =
          if amount < 0 then (Amount.of_int (-amount), true)
          else (Amount.of_int amount, false)
        in
        UserAmountMap.set map acct_key (amount_t, negative) )
      entries

  let test_map1 = make_test_map [("Alice", 42); ("Bob", 99); ("Charlie", 101)]

  let test_inverse_map1 =
    make_test_map [("Alice", -42); ("Bob", -99); ("Charlie", -101)]

  let test_map2 = make_test_map [("Alice", 33); ("Bob", 102)]

  let test_inverse_map2 = make_test_map [("Alice", -33); ("Bob", -102)]

  let test_sum_map =
    make_test_map [("Alice", 75); ("Bob", 201); ("Charlie", 101)]

  let%test "equal_maps_1" = UserAmountMap.equal test_map1 test_map1

  let%test "equal_maps_2" = UserAmountMap.equal test_map2 test_map2

  let%test "equal_maps_3" = not (UserAmountMap.equal test_map1 test_map2)

  let%test "add_maps_1" =
    UserAmountMap.equal test_sum_map (UserAmountMap.add test_map1 test_map2)

  let%test "add_maps_2" =
    UserAmountMap.equal test_sum_map (UserAmountMap.add test_map2 test_map1)

  let%test "map_inverse_1" =
    UserAmountMap.equal test_inverse_map1 (UserAmountMap.inverse test_map1)

  let%test "map_inverse_2" =
    UserAmountMap.equal test_inverse_map2 (UserAmountMap.inverse test_map2)

  let%test "map_inverse_3" =
    UserAmountMap.equal test_map1
      (UserAmountMap.inverse (UserAmountMap.inverse test_map1))

  let%test "map_inverse_4" =
    UserAmountMap.equal test_map2
      (UserAmountMap.inverse (UserAmountMap.inverse test_map2))
end
