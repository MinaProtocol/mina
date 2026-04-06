open Mina_base
open Core_kernel

module ArrayN = Mina_stdlib.Bounded_types.ArrayN (struct
  (* TODO remove hardcoded value: this should bound max. number of ledger updates per block *)
  let max_array_len = 128 * 32 * (2 + 35)
end)

exception Location_deserialization_error

module Map = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('k, 'v) t = ('k * 'v) ArrayN.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  let of_stable ~f_key ~f_value ~comparator (stable : ('k, 'v) Stable.Latest.t)
      : ('k2, 'v2, 'c) Map.t =
    let f (key_bs, value_bs) = (f_key key_bs, f_value value_bs) in
    Array.map stable ~f |> Map.of_sorted_array comparator |> Or_error.ok_exn

  let to_stable ~f_key ~f_value (map : ('k, 'v, 'c) Map.t) :
      ('k2, 'v2) Stable.Latest.t =
    Map.to_alist ~key_order:`Increasing map
    |> List.map ~f:(fun (k, v) -> (f_key k, f_value v))
    |> Array.of_list
end

module Location = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_stdlib.Bigstring.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end

module Address = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Mina_stdlib.Bigstring.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      { accounts : (Location.Stable.V1.t, Account.Stable.V3.t) Map.Stable.V1.t
      ; token_owners :
          (Token_id.Stable.V2.t, Account_id.Stable.V2.t) Map.Stable.V1.t
      ; hashes : (Address.Stable.V1.t, Ledger_hash.Stable.V1.t) Map.Stable.V1.t
      ; locations :
          (Account_id.Stable.V2.t, Location.Stable.V1.t) Map.Stable.V1.t
      ; non_existent_accounts : Account_id.Stable.V2.t ArrayN.Stable.V1.t
      }

    let to_latest = Fn.id
  end
end]

module type S = sig
  type t

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t
    end
  end]

  val of_stable : ledger_depth:int -> Stable.Latest.t -> t

  val to_stable : ledger_depth:int -> t -> Stable.Latest.t
end

module F (Location : Merkle_ledger.Location_intf.S) = struct
  type t =
    { accounts : Account.t Location.Map.t
    ; token_owners : Account_id.t Token_id.Map.t
    ; hashes : Ledger_hash.t Location.Addr.Map.t
    ; locations : Location.t Account_id.Map.t
    ; non_existent_accounts : Account_id.Set.t
    }

  let location_of_stable ~ledger_depth x =
    Location.parse ~ledger_depth x
    |> Result.map_error ~f:(fun () -> Location_deserialization_error)
    |> Result.ok_exn

  let location_to_stable = Location.serialize

  let address_of_stable ~ledger_depth data =
    location_of_stable ~ledger_depth data |> Location.to_path_exn

  let address_to_stable ~ledger_depth addr =
    location_to_stable ~ledger_depth
    @@
    if Location.Addr.is_leaf ~ledger_depth addr then Location.Account addr
    else Location.Hash addr

  let of_stable ~ledger_depth (stable : Stable.Latest.t) : t =
    let f_key = ident in
    let f_value = ident in
    { accounts =
        Map.of_stable
          ~f_key:(location_of_stable ~ledger_depth)
          ~f_value
          ~comparator:(module Location)
          stable.accounts
    ; token_owners =
        Map.of_stable ~f_key ~f_value
          ~comparator:(module Token_id)
          stable.token_owners
    ; hashes =
        Map.of_stable
          ~f_key:(address_of_stable ~ledger_depth)
          ~f_value
          ~comparator:(module Location.Addr)
          stable.hashes
    ; locations =
        Map.of_stable ~f_key
          ~f_value:(location_of_stable ~ledger_depth)
          ~comparator:(module Account_id)
          stable.locations
    ; non_existent_accounts =
        Account_id.Set.of_array stable.non_existent_accounts
    }

  let to_stable ~ledger_depth (t : t) : Stable.Latest.t =
    let f_key = ident in
    let f_value = ident in
    { accounts =
        Map.to_stable
          ~f_key:(location_to_stable ~ledger_depth)
          ~f_value t.accounts
    ; token_owners = Map.to_stable ~f_key ~f_value t.token_owners
    ; hashes =
        Map.to_stable ~f_key:(address_to_stable ~ledger_depth) ~f_value t.hashes
    ; locations =
        Map.to_stable ~f_key
          ~f_value:(location_to_stable ~ledger_depth)
          t.locations
    ; non_existent_accounts = Account_id.Set.to_array t.non_existent_accounts
    }
end
