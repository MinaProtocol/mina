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
  module Amount = Currency.Amount.Signed

  module UserAmountMap :
    MapWithGroupOpsS with type key = string and type value = Amount.t =
  struct
    type key = string

    type value = Amount.t

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

    let add map1 map2 =
      let new_map = Hashtbl.copy map1 in
      let keys2 = Hashtbl.to_seq_keys map2 in
      let sum_points key2 =
        let amount2 =
          match Hashtbl.find_opt map2 key2 with
          | Some v -> v
          | None -> assert false
        in
        match Hashtbl.find_opt new_map key2 with
        | Some amount1 ->
            let sum =
              match Amount.add amount1 amount2 with
              | Some v -> v
              | None -> assert false
            in
            Hashtbl.replace new_map key2 sum
        | None -> Hashtbl.add new_map key2 amount2
      in
      Seq.iter sum_points keys2 ; new_map

    let inverse map =
      let new_map = identity () in
      Hashtbl.iter
        (fun key amount -> Hashtbl.add new_map key (Amount.negate amount))
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
    let amount_of_int n =
      if n >= 0 then Currency.Amount.of_int n |> Amount.of_unsigned
      else Currency.Amount.of_int (-n) |> Amount.of_unsigned |> Amount.negate
    in
    Core.List.fold
      ~init:(UserAmountMap.identity ())
      ~f:(fun map (acct_key, amount) ->
        UserAmountMap.set map acct_key (amount_of_int amount) )
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
