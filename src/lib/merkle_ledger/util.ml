open Core

module type Inputs_intf = sig
  module Location : sig
    type t
  end

  module Account : sig
    type t
  end

  module Addr : Merkle_address.S

  module Base : sig
    type t

    val get : t -> Location.t -> Account.t option
  end

  val location_of_addr : Addr.t -> Location.t
end

module Make (Inputs : Inputs_intf) : sig
  val get_all_accounts_rooted_at_exn :
    Inputs.Base.t -> Inputs.Addr.t -> (Inputs.Addr.t * Inputs.Account.t) list
end = struct
  let get_all_accounts_rooted_at_exn t address =
    let open Inputs in
    let result =
      Addr.Range.fold (Addr.Range.subtree_range address) ~init:[]
        ~f:(fun bit_index acc ->
          let account = Base.get t (location_of_addr bit_index) in
          (bit_index, account) :: acc )
    in
    List.rev_filter_map result ~f:(function
      | _, None -> None
      | addr, Some account -> Some (addr, account) )
end
