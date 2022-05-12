(* test_common.ml -- code common to tests *)

open Core_kernel
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs.Engine

  let send_zkapp ~logger node parties =
    [%log info] "Sending zkApp"
      ~metadata:[ ("parties", Mina_base.Parties.to_yojson parties) ] ;
    match%bind.Deferred Network.Node.send_zkapp ~logger node ~parties with
    | Ok _zkapp_id ->
        [%log info] "ZkApp transaction sent" ;
        Malleable_error.return ()
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error sending zkApp"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error_format "Error sending zkApp: %s" err_str

  let send_invalid_zkapp ~logger node parties substring =
    [%log info] "Sending zkApp, expected to fail" ;
    match%bind.Deferred Network.Node.send_zkapp ~logger node ~parties with
    | Ok _zkapp_id ->
        [%log error] "ZkApp transaction succeeded, expected error \"%s\""
          substring ;
        Malleable_error.hard_error_format
          "ZkApp transaction succeeded, expected error \"%s\"" substring
    | Error err ->
        let err_str = Error.to_string_mach err in
        if String.is_substring ~substring err_str then (
          [%log info] "ZkApp transaction failed as expected"
            ~metadata:[ ("error", `String err_str) ] ;
          Malleable_error.return () )
        else (
          [%log error]
            "Error sending zkApp, for a reason other than the expected \"%s\""
            substring
            ~metadata:[ ("error", `String err_str) ] ;
          Malleable_error.hard_error_format
            "ZkApp transaction failed: %s, but expected \"%s\"" err_str
            substring )

  let get_account_permissions ~logger node account_id =
    [%log info] "Getting permissions for account"
      ~metadata:[ ("account_id", Mina_base.Account_id.to_yojson account_id) ] ;
    match%bind.Deferred
      Network.Node.get_account_permissions ~logger node ~account_id
    with
    | Ok permissions ->
        [%log info] "Got account permissions" ;
        Malleable_error.return permissions
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error getting account permissions"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error (Error.of_string err_str)

  let get_account_update ~logger node account_id =
    [%log info] "Getting update for account"
      ~metadata:[ ("account_id", Mina_base.Account_id.to_yojson account_id) ] ;
    match%bind.Deferred
      Network.Node.get_account_update ~logger node ~account_id
    with
    | Ok update ->
        [%log info] "Got account update" ;
        Malleable_error.return update
    | Error err ->
        let err_str = Error.to_string_mach err in
        [%log error] "Error getting account update"
          ~metadata:[ ("error", `String err_str) ] ;
        Malleable_error.hard_error (Error.of_string err_str)

  let compatible_item req_item ledg_item ~equal =
    match (req_item, ledg_item) with
    | Mina_base.Zkapp_basic.Set_or_keep.Keep, _ ->
        true
    | Set v1, Mina_base.Zkapp_basic.Set_or_keep.Set v2 ->
        equal v1 v2
    | Set _, Keep ->
        false

  let compatible_updates ~(ledger_update : Mina_base.Party.Update.t)
      ~(requested_update : Mina_base.Party.Update.t) : bool =
    (* the "update" in the ledger is derived from the account

       if the requested update has `Set` for a field, we
       should see `Set` for the same value in the ledger update

       if the requested update has `Keep` for a field, any
       value in the ledger update is acceptable

       for the app state, we apply this principle element-wise
    *)
    let app_states_compat =
      let fs_requested =
        Pickles_types.Vector.Vector_8.to_list requested_update.app_state
      in
      let fs_ledger =
        Pickles_types.Vector.Vector_8.to_list ledger_update.app_state
      in
      List.for_all2_exn fs_requested fs_ledger ~f:(fun req ledg ->
          compatible_item req ledg ~equal:Pickles.Backend.Tick.Field.equal)
    in
    let delegates_compat =
      compatible_item requested_update.delegate ledger_update.delegate
        ~equal:Signature_lib.Public_key.Compressed.equal
    in
    let verification_keys_compat =
      compatible_item requested_update.verification_key
        ledger_update.verification_key
        ~equal:
          [%equal:
            ( Pickles.Side_loaded.Verification_key.t
            , Pickles.Backend.Tick.Field.t )
            With_hash.t]
    in
    let permissions_compat =
      compatible_item requested_update.permissions ledger_update.permissions
        ~equal:Mina_base.Permissions.equal
    in
    let zkapp_uris_compat =
      compatible_item requested_update.zkapp_uri ledger_update.zkapp_uri
        ~equal:String.equal
    in
    let token_symbols_compat =
      compatible_item requested_update.token_symbol ledger_update.token_symbol
        ~equal:String.equal
    in
    let timings_compat =
      compatible_item requested_update.timing ledger_update.timing
        ~equal:Mina_base.Party.Update.Timing_info.equal
    in
    let voting_fors_compat =
      compatible_item requested_update.voting_for ledger_update.voting_for
        ~equal:Mina_base.State_hash.equal
    in
    List.for_all
      [ app_states_compat
      ; delegates_compat
      ; verification_keys_compat
      ; permissions_compat
      ; zkapp_uris_compat
      ; token_symbols_compat
      ; timings_compat
      ; voting_fors_compat
      ]
      ~f:Fn.id

  (* [logs] is a string containing the entire replayer output *)
  let check_replayer_logs ~logger logs =
    let error_logs =
      String.split logs ~on:'\n'
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:{|"level":"Error"|}
             || String.is_substring log ~substring:{|"level":"Fatal"|})
    in
    if List.is_empty error_logs then (
      [%log info] "The replayer encountered no errors" ;
      Malleable_error.return () )
    else
      let error = String.concat error_logs ~sep:"\n  " in
      Malleable_error.hard_error_string ("Replayer errors:\n  " ^ error)
end
