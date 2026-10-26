open Core_kernel

module type Inputs_intf = sig
  module Location : Location_intf.S

  module Location_binable : Hashable.S_binable with type t := Location.t

  module Key : Intf.Key

  module Token_id : Intf.Token_id

  module Account_id :
    Intf.Account_id with type key := Key.t and type token_id := Token_id.t

  module Balance : Intf.Balance

  module Account :
    Intf.Account
      with type balance := Balance.t
       and type account_id := Account_id.t
       and type token_id := Token_id.t

  module Hash : Intf.Hash with type account := Account.t

  module Base : sig
    type t

    val get : t -> Location.t -> Account.t option

    val last_filled : t -> Location.t option
  end

  val get_hash : Base.t -> Location.t -> Hash.t

  val location_of_account_addr : Location.Addr.t -> Location.t

  val location_of_hash_addr : Location.Addr.t -> Location.t

  val ledger_depth : Base.t -> int

  val set_raw_hash_batch : Base.t -> (Location.t * Hash.t) list -> unit

  (** Write the accounts at their locations, and update the indexes kept for
      the accounts that [reindex] selects. *)
  val set_raw_account_batch :
       reindex:(Location.t * Account.t -> bool)
    -> Base.t
    -> (Location.t * Account.t) list
    -> unit

  val set_location_batch :
       last_location:Location.t
    -> Base.t
    -> (Account_id.t * Location.t) Mina_stdlib.Nonempty_list.t
    -> unit
end

module type S = sig
  type base

  type location

  type addr

  type account

  type hash

  type hash_cache

  val get_all_accounts_rooted_at_exn : base -> addr -> (addr * account) list

  val set_hash_batch : base -> (location * hash) list -> unit

  val set_batch :
    ?hash_cache:hash_cache -> base -> (location * account) list -> unit

  (** [set_batch], updating the indexes kept for an account only if [reindex]
      selects it: an account replacing one with the same identifier keeps the
      entries of the one it replaces. *)
  val set_batch_reindexing :
       ?hash_cache:hash_cache
    -> reindex:(location * account -> bool)
    -> base
    -> (location * account) list
    -> unit

  val set_batch_accounts : base -> (addr * account) list -> unit

  val set_all_accounts_rooted_at_exn : base -> addr -> account list -> unit
end

module Make (Inputs : Inputs_intf) :
  S
    with type base := Inputs.Base.t
     and type location := Inputs.Location.t
     and type addr := Inputs.Location.Addr.t
     and type account := Inputs.Account.t
     and type hash := Inputs.Hash.t
     and type hash_cache := Inputs.Hash.t Inputs.Location.Addr.Map.t = struct
  let get_all_accounts_rooted_at_exn t address =
    let open Inputs in
    let result =
      Location.Addr.Range.fold
        (Location.Addr.Range.subtree_range ~ledger_depth:(Inputs.ledger_depth t)
           address )
        ~init:[]
        ~f:(fun bit_index acc ->
          let account = Base.get t (location_of_account_addr bit_index) in
          (bit_index, account) :: acc )
    in
    List.rev_filter_map result ~f:(function
      | _, None ->
          None
      | addr, Some account ->
          Some (addr, account) )

  let lookup_hash ?hash_cache ~compute loc =
    let res =
      let%bind.Option addr =
        Option.try_with (fun () -> Inputs.Location.to_path_exn loc)
      in
      let%bind.Option m = hash_cache in
      Map.find m addr
    in
    match res with Some x -> x | _ -> compute ()

  let rec compute_affected_locations_and_hashes ?hash_cache t
      locations_and_hashes acc =
    let ledger_depth = Inputs.ledger_depth t in
    if not @@ List.is_empty locations_and_hashes then
      let height =
        Inputs.Location.height ~ledger_depth
        @@ fst
        @@ List.hd_exn locations_and_hashes
      in
      if height < ledger_depth then
        let parents_to_children =
          List.fold locations_and_hashes ~init:Inputs.Location.Map.empty
            ~f:(fun parents_to_children (location, hash) ->
              let parent_location = Inputs.Location.parent location in
              Map.update parents_to_children parent_location ~f:(function
                | Some (`One_side (sibling_location, sibling_hash)) ->
                    assert (
                      not (Inputs.Location.equal location sibling_location) ) ;
                    (* If we have already recorded the sibling, we can compute
                       the hash now.
                    *)
                    let parent_hash =
                      lookup_hash ?hash_cache parent_location
                        ~compute:(fun () ->
                          let left_hash, right_hash =
                            Inputs.Location.order_siblings location hash
                              sibling_hash
                          in
                          Inputs.Hash.merge ~height left_hash right_hash )
                    in
                    `Hash parent_hash
                | Some (`Hash _) ->
                    assert false
                | None ->
                    (* This is the first child of its parent that we have
                       encountered.
                    *)
                    `One_side (location, hash) ) )
        in
        let rev_parent_locations_and_hashes =
          Map.fold parents_to_children ~init:[] ~f:(fun ~key ~data acc ->
              match data with
              | `One_side (location, hash) ->
                  (* We haven't recorded the sibling, so query the ledger to get
                     the hash.
                  *)
                  let parent_hash =
                    lookup_hash ?hash_cache key ~compute:(fun () ->
                        let sibling_location =
                          Inputs.Location.sibling location
                        in
                        let sibling_hash = Inputs.get_hash t sibling_location in
                        let left_hash, right_hash =
                          Inputs.Location.order_siblings location hash
                            sibling_hash
                        in
                        Inputs.Hash.merge ~height left_hash right_hash )
                  in
                  (key, parent_hash) :: acc
              | `Hash parent_hash ->
                  (* We have already computed the hash above. *)
                  (key, parent_hash) :: acc )
        in
        compute_affected_locations_and_hashes ?hash_cache t
          rev_parent_locations_and_hashes
          (List.rev_append rev_parent_locations_and_hashes acc)
      else acc
    else acc

  let set_hash_batch ?hash_cache t locations_and_hashes =
    Inputs.set_raw_hash_batch t
      (compute_affected_locations_and_hashes ?hash_cache t locations_and_hashes
         locations_and_hashes )

  let compute_last_index addresses =
    Mina_stdlib.Nonempty_list.map addresses
      ~f:(Fn.compose Inputs.Location.Addr.to_int Inputs.Location.to_path_exn)
    |> Mina_stdlib.Nonempty_list.max_elt ~compare:Int.compare

  let set_raw_addresses t addresses_and_accounts =
    let ledger_depth = Inputs.ledger_depth t in
    Option.iter (Mina_stdlib.Nonempty_list.of_list_opt addresses_and_accounts)
      ~f:(fun nonempty_addresses_and_accounts ->
        let key_locations =
          Mina_stdlib.Nonempty_list.map nonempty_addresses_and_accounts
            ~f:(fun (address, account) ->
              (Inputs.Account.identifier account, address) )
        in
        let new_last_location =
          let current_last_index =
            let open Option.Let_syntax in
            let%map last_location = Inputs.Base.last_filled t in
            Inputs.Location.Addr.to_int
            @@ Inputs.Location.to_path_exn last_location
          in
          let foreign_last_index =
            compute_last_index
              (Mina_stdlib.Nonempty_list.map nonempty_addresses_and_accounts
                 ~f:fst )
          in
          let max_index_in_all_accounts =
            Option.value_map current_last_index ~default:foreign_last_index
              ~f:(fun max_index -> Int.max max_index foreign_last_index)
          in
          Inputs.Location.(
            Account (Addr.of_int_exn ~ledger_depth max_index_in_all_accounts))
        in
        let last_location = new_last_location in
        Inputs.set_location_batch ~last_location t key_locations )

  (* TODO: When we do batch on a database, we should add accounts, locations and hashes
     simultaneously for full atomicity. *)
  let set_batch_reindexing ?hash_cache ~reindex t locations_and_accounts =
    set_raw_addresses t (List.filter locations_and_accounts ~f:reindex) ;
    Inputs.set_raw_account_batch ~reindex t locations_and_accounts ;
    set_hash_batch ?hash_cache t
    @@ List.map locations_and_accounts ~f:(fun (location, account) ->
           let addr = Inputs.Location.to_path_exn location in
           let account_hash =
             lookup_hash ?hash_cache location ~compute:(fun () ->
                 Inputs.Hash.hash_account account )
           in
           (Inputs.location_of_hash_addr addr, account_hash) )

  let set_batch ?hash_cache t locations_and_accounts =
    set_batch_reindexing ?hash_cache ~reindex:(Fn.const true) t
      locations_and_accounts

  let set_batch_accounts t addresses_and_accounts =
    set_batch t
    @@ List.map addresses_and_accounts ~f:(fun (addr, account) ->
           (Inputs.location_of_account_addr addr, account) )

  let set_all_accounts_rooted_at_exn t address accounts =
    let addresses =
      Sequence.to_list
      @@ Inputs.Location.Addr.Range.subtree_range_seq
           ~ledger_depth:(Inputs.ledger_depth t) address
    in
    let num_accounts = List.length accounts in
    List.(zip_exn (take addresses num_accounts) accounts)
    |> set_batch_accounts t

  let set_hash_batch = set_hash_batch ?hash_cache:None
end
