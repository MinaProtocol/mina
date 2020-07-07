open Core

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

  val set_raw_account_batch : Base.t -> (Location.t * Account.t) list -> unit

  val set_location_batch :
       last_location:Location.t
    -> Base.t
    -> (Account_id.t * Location.t) Non_empty_list.t
    -> unit
end

module Make (Inputs : Inputs_intf) : sig
  val get_all_accounts_rooted_at_exn :
       Inputs.Base.t
    -> Inputs.Location.Addr.t
    -> (Inputs.Location.Addr.t * Inputs.Account.t) list

  val set_hash_batch :
    Inputs.Base.t -> (Inputs.Location.t * Inputs.Hash.t) list -> unit

  val set_batch :
    Inputs.Base.t -> (Inputs.Location.t * Inputs.Account.t) list -> unit

  val set_batch_accounts :
    Inputs.Base.t -> (Inputs.Location.Addr.t * Inputs.Account.t) list -> unit

  val set_all_accounts_rooted_at_exn :
    Inputs.Base.t -> Inputs.Location.Addr.t -> Inputs.Account.t list -> unit
end = struct
  let get_all_accounts_rooted_at_exn t address =
    let open Inputs in
    let result =
      Location.Addr.Range.fold
        (Location.Addr.Range.subtree_range
           ~ledger_depth:(Inputs.ledger_depth t) address)
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

  let rec compute_affected_locations_and_hashes t locations_and_hashes acc =
    let ledger_depth = Inputs.ledger_depth t in
    let locations, _ = List.unzip locations_and_hashes in
    if not @@ List.is_empty locations then
      let height =
        Inputs.Location.height ~ledger_depth @@ List.hd_exn locations
      in
      if height < ledger_depth then
        let location_to_hash_table =
          Inputs.Location_binable.Table.of_alist_exn locations_and_hashes
        in
        let _, parent_locations_and_hashes =
          List.fold locations_and_hashes ~init:([], [])
            ~f:(fun (processed_locations, parent_locations_and_hashes)
               (location, hash)
               ->
              if
                List.mem processed_locations location
                  ~equal:Inputs.Location.equal
              then (processed_locations, parent_locations_and_hashes)
              else
                let sibling_location = Inputs.Location.sibling location in
                let sibling_hash =
                  Option.value ~default:(Inputs.get_hash t sibling_location)
                  @@ Hashtbl.find location_to_hash_table sibling_location
                in
                let parent_hash =
                  let left_hash, right_hash =
                    Inputs.Location.order_siblings location hash sibling_hash
                  in
                  Inputs.Hash.merge ~height left_hash right_hash
                in
                ( location :: sibling_location :: processed_locations
                , (Inputs.Location.parent location, parent_hash)
                  :: parent_locations_and_hashes ) )
        in
        compute_affected_locations_and_hashes t parent_locations_and_hashes
          (List.append parent_locations_and_hashes acc)
      else acc
    else acc

  let set_hash_batch t locations_and_hashes =
    Inputs.set_raw_hash_batch t
      (compute_affected_locations_and_hashes t locations_and_hashes
         locations_and_hashes)

  let compute_last_index addresses =
    Non_empty_list.map addresses
      ~f:(Fn.compose Inputs.Location.Addr.to_int Inputs.Location.to_path_exn)
    |> Non_empty_list.max_elt ~compare:Int.compare

  let set_raw_addresses t addresses_and_accounts =
    let ledger_depth = Inputs.ledger_depth t in
    Option.iter (Non_empty_list.of_list_opt addresses_and_accounts)
      ~f:(fun nonempty_addresses_and_accounts ->
        let key_locations =
          Non_empty_list.map nonempty_addresses_and_accounts
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
              (Non_empty_list.map nonempty_addresses_and_accounts ~f:fst)
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
     simulatenously for full atomicity. *)
  let set_batch t locations_and_accounts =
    set_raw_addresses t locations_and_accounts ;
    Inputs.set_raw_account_batch t locations_and_accounts ;
    set_hash_batch t
    @@ List.map locations_and_accounts ~f:(fun (location, account) ->
           ( Inputs.location_of_hash_addr (Inputs.Location.to_path_exn location)
           , Inputs.Hash.hash_account account ) )

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
end
