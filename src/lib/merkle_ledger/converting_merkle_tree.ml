open Core_kernel

module Make (Inputs : sig
  include Intf.Inputs.Intf

  type converted_account

  val convert : Account.t -> converted_account
end)
(Primary_ledger : Intf.Ledger.S
                    with module Location = Inputs.Location
                     and module Addr = Inputs.Location.Addr
                     and type key := Inputs.Key.t
                     and type token_id := Inputs.Token_id.t
                     and type token_id_set := Inputs.Token_id.Set.t
                     and type account := Inputs.Account.t
                     and type root_hash := Inputs.Hash.t
                     and type hash := Inputs.Hash.t
                     and type account_id := Inputs.Account_id.t
                     and type account_id_set := Inputs.Account_id.Set.t)
(Converting_ledger : Intf.Ledger.S
                       with module Location = Inputs.Location
                        and module Addr = Inputs.Location.Addr
                        and type key := Inputs.Key.t
                        and type token_id := Inputs.Token_id.t
                        and type token_id_set := Inputs.Token_id.Set.t
                        and type account := Inputs.converted_account
                        and type root_hash := Inputs.Hash.t
                        and type hash := Inputs.Hash.t
                        and type account_id := Inputs.Account_id.t
                        and type account_id_set := Inputs.Account_id.Set.t) : sig
  include
    Intf.Ledger.S
      with module Location = Inputs.Location
       and module Addr = Inputs.Location.Addr
       and type key := Inputs.Key.t
       and type token_id := Inputs.Token_id.t
       and type token_id_set := Inputs.Token_id.Set.t
       and type account := Inputs.Account.t
       and type root_hash := Inputs.Hash.t
       and type hash := Inputs.Hash.t
       and type account_id := Inputs.Account_id.t
       and type account_id_set := Inputs.Account_id.Set.t

  val create : Primary_ledger.t -> Converting_ledger.t option -> t

  val primary_ledger : t -> Primary_ledger.t

  val converting_ledger : t -> Converting_ledger.t option
end = struct
  let convert = Inputs.convert

  module Location = Inputs.Location
  module Addr = Inputs.Location.Addr
  module Path = Primary_ledger.Path

  type path = Primary_ledger.path

  type index = int

  type t =
    { primary_ledger : Primary_ledger.t
    ; converting_ledger : Converting_ledger.t option
    }

  let create primary_ledger converting_ledger =
    { primary_ledger; converting_ledger }

  let primary_ledger { primary_ledger; _ } = primary_ledger

  let converting_ledger { converting_ledger; _ } = converting_ledger

  let depth t = Primary_ledger.depth t.primary_ledger

  let num_accounts t = Primary_ledger.num_accounts t.primary_ledger

  let merkle_path_at_addr_exn t addr =
    Primary_ledger.merkle_path_at_addr_exn t.primary_ledger addr

  let get_inner_hash_at_addr_exn t addr =
    Primary_ledger.get_inner_hash_at_addr_exn t.primary_ledger addr

  let set_all_accounts_rooted_at_exn t addr accounts =
    Primary_ledger.set_all_accounts_rooted_at_exn t.primary_ledger addr accounts ;
    Option.iter t.converting_ledger ~f:(fun converting_ledger ->
        Converting_ledger.set_all_accounts_rooted_at_exn converting_ledger addr
          (List.map ~f:convert accounts))

  let set_batch_accounts t addressed_accounts =
    Primary_ledger.set_batch_accounts t.primary_ledger addressed_accounts ;
    Option.iter t.converting_ledger
      ~f:(fun converting_ledger ->
        Converting_ledger.set_batch_accounts converting_ledger
          (List.map
             ~f:(fun (addr, account) -> (addr, convert account))
             addressed_accounts ))

  let get_all_accounts_rooted_at_exn t addr =
    Primary_ledger.get_all_accounts_rooted_at_exn t.primary_ledger addr

  let merkle_root t = Primary_ledger.merkle_root t.primary_ledger

  let to_list t = Primary_ledger.to_list t.primary_ledger

  let to_list_sequential t = Primary_ledger.to_list_sequential t.primary_ledger

  let iteri t ~f = Primary_ledger.iteri t.primary_ledger ~f

  let foldi t ~init ~f = Primary_ledger.foldi t.primary_ledger ~init ~f

  let foldi_with_ignored_accounts t account_ids ~init ~f =
    Primary_ledger.foldi_with_ignored_accounts t.primary_ledger account_ids
      ~init ~f

  let fold_until t ~init ~f ~finish =
    Primary_ledger.fold_until t.primary_ledger ~init ~f ~finish

  let accounts t = Primary_ledger.accounts t.primary_ledger

  let tokens t = Primary_ledger.tokens t.primary_ledger

  let token_owner t token_id =
    Primary_ledger.token_owner t.primary_ledger token_id

  let token_owners t = Primary_ledger.token_owners t.primary_ledger

  let location_of_account t account_id =
    Primary_ledger.location_of_account t.primary_ledger account_id

  let location_of_account_batch t account_ids =
    Primary_ledger.location_of_account_batch t.primary_ledger account_ids

  let get_or_create_account t account_id account =
    let open Or_error.Let_syntax in
    let%bind res =
      Primary_ledger.get_or_create_account t.primary_ledger account_id account
    in
    let%map converting_res =
      Option.value_map ~default:(return res)
        ~f:(fun converting_ledger ->
          Converting_ledger.get_or_create_account converting_ledger account_id
            (convert account) )
        t.converting_ledger
    in
    let () =
      match (res, converting_res) with
      | (`Added, _), (`Existed, _) | (`Existed, _), (`Added, _) ->
          failwith "Inconsistent account state in converting ledger"
      | (_, loc_res), (_, loc_conv) ->
          if not (Location.equal loc_res loc_conv) then
            failwith "Inconsistent location in converting ledger"
    in
    res

  let close t =
    Primary_ledger.close t.primary_ledger ;
    Option.iter ~f:Converting_ledger.close t.converting_ledger

  let last_filled t = Primary_ledger.last_filled t.primary_ledger

  let get_uuid t = Primary_ledger.get_uuid t.primary_ledger

  let get_directory t = Primary_ledger.get_directory t.primary_ledger

  let get t location = Primary_ledger.get t.primary_ledger location

  let get_batch t locations =
    Primary_ledger.get_batch t.primary_ledger locations

  let set t location account =
    Primary_ledger.set t.primary_ledger location account ;
    Option.iter t.converting_ledger ~f:(fun converting_ledger ->
        Converting_ledger.set converting_ledger location (convert account))

  let set_batch ?hash_cache t located_accounts =
    Primary_ledger.set_batch ?hash_cache t.primary_ledger located_accounts ;
    Option.iter t.converting_ledger ~f:(fun converting_ledger ->
        Converting_ledger.set_batch converting_ledger
          (List.map
             ~f:(fun (loc, account) -> (loc, convert account))
             located_accounts ))

  let get_at_index_exn t idx =
    Primary_ledger.get_at_index_exn t.primary_ledger idx

  let set_at_index_exn t idx account =
    Primary_ledger.set_at_index_exn t.primary_ledger idx account ;
    Option.iter t.converting_ledger ~f:(fun converting_ledger ->
        Converting_ledger.set_at_index_exn converting_ledger idx
          (convert account))

  let index_of_account_exn t account_id =
    Primary_ledger.index_of_account_exn t.primary_ledger account_id

  let merkle_path t location =
    Primary_ledger.merkle_path t.primary_ledger location

  let merkle_path_at_index_exn t idx =
    Primary_ledger.merkle_path_at_index_exn t.primary_ledger idx

  let merkle_path_batch t locations =
    Primary_ledger.merkle_path_batch t.primary_ledger locations

  let wide_merkle_path_batch t locations =
    Primary_ledger.wide_merkle_path_batch t.primary_ledger locations

  let get_hash_batch_exn t locations =
    Primary_ledger.get_hash_batch_exn t.primary_ledger locations

  let detached_signal t = Primary_ledger.detached_signal t.primary_ledger
end
