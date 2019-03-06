open Core

module type Inputs_intf = sig
  module Location : Location_intf.S

  module Key : Intf.Key

  module Account : Intf.Account with type key := Key.t

  module Hash : Intf.Hash with type account := Account.t

  module Depth : Intf.Depth

  module Base : sig
    type t

    val get : t -> Location.t -> Account.t option
  end

  val get_hash : Base.t -> Location.t -> Hash.t

  val location_of_account_addr : Location.Addr.t -> Location.t

  val location_of_hash_addr : Location.Addr.t -> Location.t

  val set_raw_hash_batch : Base.t -> (Location.t * Hash.t) list -> unit

  val set_raw_account_batch : Base.t -> (Location.t * Account.t) list -> unit
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
      Location.Addr.Range.fold (Location.Addr.Range.subtree_range address)
        ~init:[] ~f:(fun bit_index acc ->
          let account = Base.get t (location_of_account_addr bit_index) in
          (bit_index, account) :: acc )
    in
    List.rev_filter_map result ~f:(function
      | _, None -> None
      | addr, Some account -> Some (addr, account) )

  let rec compute_affected_locations_and_hashes t locations_and_hashes acc =
    let locations, _ = List.unzip locations_and_hashes in
    if not @@ List.is_empty locations then
      let height = Inputs.Location.height @@ List.hd_exn locations in
      if height < Inputs.Depth.depth then
        let location_to_hash_table =
          Inputs.Location.Table.of_alist_exn locations_and_hashes
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

  (* TODO: When we do batch on a database, we should add accounts and hashes
     simulatenously to full atomicity. We should do this in the future. *)
  let set_batch t locations_and_accounts =
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
      Sequence.to_list @@ Inputs.Location.Addr.Range.subtree_range_seq address
    in
    let num_accounts = List.length accounts in
    List.(zip_exn (take addresses num_accounts) accounts)
    |> set_batch_accounts t
end
