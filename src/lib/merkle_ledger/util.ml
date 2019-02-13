open Core

module Make (Location : sig
  type t
end) (Account : sig
  type t
end)
(Addr : Merkle_address.S)
(Base : sig
          type t

          type location

          type addr

          type account

          val get : t -> location -> account option

          val addr_to_location : addr -> location
        end
        with type location := Location.t
         and type addr := Addr.t
         and type account := Account.t) :
  sig
    type t

    type addr

    type account

    val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list
  end
  with type t := Base.t
   and type addr := Addr.t
   and type account := Account.t = struct
  let get_all_accounts_rooted_at_exn t address =
    let first_node, last_node = Addr.Range.subtree_range address in
    let result =
      Addr.Range.fold (first_node, last_node) ~init:[] ~f:(fun bit_index acc ->
          let account = Base.get t (Base.addr_to_location bit_index) in
          (bit_index, account) :: acc )
    in
    List.rev_filter_map result ~f:(function
      | _, None -> None
      | addr, Some account -> Some (addr, account) )
end
