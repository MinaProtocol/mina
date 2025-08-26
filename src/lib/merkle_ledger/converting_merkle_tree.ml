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
                        and type account_id_set := Inputs.Account_id.Set.t) :
  Intf.Ledger.Converting.S
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
     and type converted_account := Inputs.converted_account
     and type primary_ledger = Primary_ledger.t
     and type converting_ledger = Converting_ledger.t = struct
  let convert = Inputs.convert

  module Location = Inputs.Location
  module Addr = Inputs.Location.Addr
  module Path = Primary_ledger.Path

  type path = Primary_ledger.path

  type index = int

  type primary_ledger = Primary_ledger.t

  type converting_ledger = Converting_ledger.t

  type t =
    { primary_ledger : Primary_ledger.t
    ; converting_ledger : Converting_ledger.t
    }

  let of_ledgers primary_ledger converting_ledger =
    { primary_ledger; converting_ledger }

  let of_ledgers_with_migration primary_ledger converting_ledger =
    assert (Converting_ledger.num_accounts converting_ledger = 0) ;
    let accounts =
      Primary_ledger.foldi primary_ledger ~init:[] ~f:(fun addr acc account ->
          (addr, convert account) :: acc )
    in
    Converting_ledger.set_batch_accounts converting_ledger accounts ;
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
    Converting_ledger.set_all_accounts_rooted_at_exn t.converting_ledger addr
      (List.map ~f:convert accounts)

  let set_batch_accounts t addressed_accounts =
    Primary_ledger.set_batch_accounts t.primary_ledger addressed_accounts ;
    Converting_ledger.set_batch_accounts t.converting_ledger
      (List.map
         ~f:(fun (addr, account) -> (addr, convert account))
         addressed_accounts )

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
      Converting_ledger.get_or_create_account t.converting_ledger account_id
        (convert account)
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
    Converting_ledger.close t.converting_ledger

  let last_filled t = Primary_ledger.last_filled t.primary_ledger

  let get_uuid t = Primary_ledger.get_uuid t.primary_ledger

  let get_directory t = Primary_ledger.get_directory t.primary_ledger

  let get t location = Primary_ledger.get t.primary_ledger location

  let get_batch t locations =
    Primary_ledger.get_batch t.primary_ledger locations

  let set t location account =
    Primary_ledger.set t.primary_ledger location account ;
    Converting_ledger.set t.converting_ledger location (convert account)

  let set_batch ?hash_cache t located_accounts =
    Primary_ledger.set_batch ?hash_cache t.primary_ledger located_accounts ;
    Converting_ledger.set_batch t.converting_ledger
      (List.map
         ~f:(fun (loc, account) -> (loc, convert account))
         located_accounts )

  let get_at_index_exn t idx =
    Primary_ledger.get_at_index_exn t.primary_ledger idx

  let set_at_index_exn t idx account =
    Primary_ledger.set_at_index_exn t.primary_ledger idx account ;
    Converting_ledger.set_at_index_exn t.converting_ledger idx (convert account)

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

module With_database_config = struct
  type t = { primary_directory : string; converting_directory : string }

  type create = Temporary | In_directories of t

  let default_converting_directory_name primary_directory_name =
    primary_directory_name ^ "_converting"

  let with_primary ~directory_name =
    { primary_directory = directory_name
    ; converting_directory = default_converting_directory_name directory_name
    }
end

module With_database (Inputs : sig
  include Intf.Inputs.Intf

  type converted_account

  val convert : Account.t -> converted_account

  val converted_equal : converted_account -> converted_account -> bool
end)
(Primary_db : Intf.Ledger.DATABASE
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
(Converting_db : Intf.Ledger.DATABASE
                   with module Location = Inputs.Location
                    and module Addr = Inputs.Location.Addr
                    and type key := Inputs.Key.t
                    and type token_id := Inputs.Token_id.t
                    and type token_id_set := Inputs.Token_id.Set.t
                    and type account := Inputs.converted_account
                    and type root_hash := Inputs.Hash.t
                    and type hash := Inputs.Hash.t
                    and type account_id := Inputs.Account_id.t
                    and type account_id_set := Inputs.Account_id.Set.t) =
struct
  include Make (Inputs) (Primary_db) (Converting_db)
  module Config = With_database_config

  let dbs_synced db1 db2 =
    Primary_db.num_accounts db1 = Converting_db.num_accounts db2
    &&
    let is_synced = ref true in
    Primary_db.iteri db1 ~f:(fun idx stable_account ->
        let expected_unstable_account = convert stable_account in
        let actual_unstable_account = Converting_db.get_at_index_exn db2 idx in
        if
          not
            (Inputs.converted_equal expected_unstable_account
               actual_unstable_account )
        then is_synced := false ) ;
    !is_synced

  let create ~config ~logger ~depth () =
    let primary_directory_name, converting_directory_name =
      match config with
      | Config.Temporary ->
          (None, None)
      | In_directories { primary_directory; converting_directory } ->
          (Some primary_directory, Some converting_directory)
    in
    let db1 =
      Primary_db.create ?directory_name:primary_directory_name ~depth ()
    in
    let db2_directory_name =
      Option.first_some converting_directory_name
      @@ Option.map
           (Primary_db.get_directory db1)
           ~f:Config.default_converting_directory_name
    in
    let db2 =
      Converting_db.create ?directory_name:db2_directory_name ~depth ()
    in
    if Converting_db.num_accounts db2 = 0 then of_ledgers_with_migration db1 db2
    else if dbs_synced db1 db2 then of_ledgers db1 db2
    else (
      [%log warn]
        "Migrating DB desync, cleaning up unstable DB and remigrating..." ;
      Converting_db.close db2 ;
      let db2 =
        Converting_db.create ?directory_name:db2_directory_name ~fresh:true
          ~depth ()
      in
      of_ledgers_with_migration db1 db2 )

  let create_checkpoint t ~config () =
    let primary' =
      Primary_db.create_checkpoint (primary_ledger t)
        ~directory_name:config.Config.primary_directory ()
    in
    let converting' =
      Converting_db.create_checkpoint (converting_ledger t)
        ~directory_name:config.converting_directory ()
    in
    of_ledgers primary' converting'

  let make_checkpoint t ~config =
    Primary_db.make_checkpoint (primary_ledger t)
      ~directory_name:config.Config.primary_directory ;
    Converting_db.make_checkpoint (converting_ledger t)
      ~directory_name:config.converting_directory
end
