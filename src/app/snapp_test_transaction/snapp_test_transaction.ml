open Core_kernel
open Async
open Mina_base
open Cli_lib.Arg_type
open Snapp_test_transaction_lib.Commands

module Flags = struct
  open Command

  let default_fee = Currency.Fee.of_formatted_string "1"

  let min_fee = Currency.Fee.of_formatted_string "0.003"

  let memo =
    Param.flag "--memo" ~doc:"STRING Memo accompanying the transaction"
      Param.(optional string)

  let fee =
    Param.flag "--fee"
      ~doc:
        (Printf.sprintf
           "FEE Amount you are willing to pay to process the transaction \
            (default: %s) (minimum: %s)"
           (Currency.Fee.to_formatted_string default_fee)
           (Currency.Fee.to_formatted_string min_fee))
      (Param.optional txn_fee)

  let snapp_account_key =
    Param.flag "--snapp-account-key"
      ~doc:"PUBLIC KEY Base58 encoded public key of the new snapp account"
      Param.(required public_key_compressed)

  let amount =
    Param.flag "--receiver-amount" ~doc:"NN Receiver amount in Mina"
      (Param.required txn_amount)

  let nonce =
    Param.flag "--nonce" ~doc:"NN Nonce of the fee payer account"
      Param.(required txn_nonce)

  let common_flags =
    Command.(
      let open Let_syntax in
      let%map keyfile =
        Param.flag "--fee-payer-key"
          ~doc:
            "KEYFILE Private key file for the fee payer of the transaction \
             (should already be in the ledger)"
          Param.(required string)
      and fee = fee
      and nonce = nonce
      and memo = memo
      and debug =
        Param.flag "--debug" Param.no_arg
          ~doc:"Debug mode, generates transaction snark"
      in
      (keyfile, fee, nonce, memo, debug))
end

let create_snapp_account =
  let create_command ~debug ~keyfile ~fee ~snapp_keyfile ~amount ~nonce ~memo ()
      =
    let open Deferred.Let_syntax in
    let%map parties =
      create_snapp_account ~debug ~keyfile ~fee ~snapp_keyfile ~amount ~nonce
        ~memo
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that creates a snapp account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and amount = Flags.amount in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~snapp_keyfile ~amount ~nonce ~memo))

let upgrade_snapp =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~verification_key ~snapp_uri ~auth () =
    let open Deferred.Let_syntax in
    let%map parties =
      upgrade_snapp ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~verification_key ~snapp_uri ~auth
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates the verification key"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and verification_key =
         Param.flag "--verification-key"
           ~doc:"VERIFICATION_KEY the verification key for the snapp account"
           Param.(required string)
       and snapp_uri_str =
         Param.flag "--snapp-uri" ~doc:"URI the URI for the snapp account"
           Param.(optional string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change the verification key"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       let snapp_uri = Snapp_basic.Set_or_keep.of_option snapp_uri_str in
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~verification_key ~snapp_uri ~auth))

let transfer_funds =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~receivers () =
    let open Deferred.Let_syntax in
    let%map parties =
      transfer_funds ~debug ~keyfile ~fee ~nonce ~memo ~receivers
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  let read_key_and_amount count =
    let read () =
      let open Deferred.Let_syntax in
      printf "Receiver Key:%!" ;
      match%bind Reader.read_line (Lazy.force Reader.stdin) with
      | `Ok key -> (
          let pk =
            Signature_lib.Public_key.Compressed.of_base58_check_exn key
          in
          printf !"Amount:%!" ;
          match%map Reader.read_line (Lazy.force Reader.stdin) with
          | `Ok amt ->
              let amount = Currency.Amount.of_formatted_string amt in
              (pk, amount)
          | `Eof ->
              failwith "Invalid amount" )
      | `Eof ->
          failwith "Invalid key"
    in
    let rec go ?(prompt = true) count keys =
      if count <= 0 then return keys
      else if prompt then (
        printf "Continue? [N/y]\n%!" ;
        match%bind Reader.read_line (Lazy.force Reader.stdin) with
        | `Ok r ->
            if String.Caseless.equal r "y" then
              let%bind key = read () in
              go (count - 1) (key :: keys)
            else return keys
        | `Eof ->
            return keys )
      else
        let%bind key = read () in
        go (count - 1) (key :: keys)
    in
    printf "Enter at most %d receivers (Base58Check encoding) and amounts\n%!"
      count ;
    let%bind ks = go ~prompt:false 1 [] in
    go (count - 1) ks
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a snapp transaction that makes multiple transfers from one \
         account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwithf "Fee must at least be %s"
           (Currency.Fee.to_formatted_string Flags.min_fee)
           () ;
       let max_keys = 10 in
       let receivers = read_key_and_amount max_keys in
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~receivers))

let update_state =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~app_state
      () =
    let open Deferred.Let_syntax in
    let%map parties =
      update_state ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~app_state
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates snapp state"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and app_state =
         Param.flag "--snapp-state"
           ~doc:
             "String(hash)|Integer(field element) a list of 8 elements that \
              represent the snapp state (Use empty string for no-op)"
           Param.(listed string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~app_state))

let update_snapp_uri =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile ~snapp_uri
      ~auth () =
    let open Deferred.Let_syntax in
    let%map parties =
      update_snapp_uri ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~snapp_uri ~auth
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates the snapp uri"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and snapp_uri =
         Param.flag "--snapp-uri"
           ~doc:"SNAPP_URI The string to be used as the updated snapp uri"
           Param.(required string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change the snapp uri"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~snapp_uri ~auth))

let update_sequence_state =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~sequence_state () =
    let open Deferred.Let_syntax in
    let%map parties =
      update_sequence_state ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~sequence_state
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates snapp state"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and sequence_state0 =
         Param.flag "--sequence-state0"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             required
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       and sequence_state1 =
         Param.flag "--sequence-state1"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       and sequence_state2 =
         Param.flag "--sequence-state2"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       and sequence_state3 =
         Param.flag "--sequence-state3"
           ~doc:"String(hash)|Integer(field element) a list of elements"
           Param.(
             optional_with_default []
               (Arg_type.comma_separated ~allow_empty:false
                  ~strip_whitespace:true string))
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let sequence_state =
         List.filter_map
           ~f:(fun s ->
             if List.is_empty s then None else Some (Array.of_list s))
           [ sequence_state0
           ; sequence_state1
           ; sequence_state2
           ; sequence_state3
           ]
       in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~sequence_state))

let update_token_symbol =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~token_symbol ~auth () =
    let open Deferred.Let_syntax in
    let%map parties =
      update_token_symbol ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~token_symbol ~auth
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:"Generate a snapp transaction that updates token symbol"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and token_symbol =
         Param.flag "--token-symbol"
           ~doc:"TOKEN_SYMBOL The string to be used as the updated token symbol"
           Param.(required string)
       and auth =
         Param.flag "--auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change the token symbol"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let auth = Util.auth_of_string auth in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~token_symbol ~auth))

let update_permissions =
  let create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
      ~permissions ~current_auth () =
    let open Deferred.Let_syntax in
    let%map parties =
      update_permissions ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
        ~permissions ~current_auth
    in
    Util.print_snapp_transaction parties ;
    ()
  in
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a snapp transaction that updates the permissions of a snapp \
         account"
      (let%map keyfile, fee, nonce, memo, debug = Flags.common_flags
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and edit_state =
         Param.flag "--edit-state" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and send =
         Param.flag "--send" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and receive =
         Param.flag "--receive" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_permissions =
         Param.flag "--set-permissions" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_delegate =
         Param.flag "--set-delegate" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_verification_key =
         Param.flag "--set-verification-key" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_snapp_uri =
         Param.flag "--set-snapp-uri" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and edit_sequence_state =
         Param.flag "--set-sequence-state" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_token_symbol =
         Param.flag "--set-token-symbol" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and increment_nonce =
         Param.flag "--increment-nonce" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and set_voting_for =
         Param.flag "--set-voting-for" ~doc:"Proof|Signature|Either|None"
           Param.(required string)
       and current_auth =
         Param.flag "--current-auth"
           ~doc:
             "Proof|Signature|Either|None Current authorization in the account \
              to change permissions"
           Param.(required string)
       in
       let fee = Option.value ~default:Flags.default_fee fee in
       let permissions : Permissions.t Snapp_basic.Set_or_keep.t =
         Snapp_basic.Set_or_keep.Set
           { Permissions.Poly.edit_state = Util.auth_of_string edit_state
           ; send = Util.auth_of_string send
           ; receive = Util.auth_of_string receive
           ; set_permissions = Util.auth_of_string set_permissions
           ; set_delegate = Util.auth_of_string set_delegate
           ; set_verification_key = Util.auth_of_string set_verification_key
           ; set_snapp_uri = Util.auth_of_string set_snapp_uri
           ; edit_sequence_state = Util.auth_of_string edit_sequence_state
           ; set_token_symbol = Util.auth_of_string set_token_symbol
           ; increment_nonce = Util.auth_of_string increment_nonce
           ; set_voting_for = Util.auth_of_string set_voting_for
           }
       in
       if Currency.Fee.(fee < Flags.min_fee) then
         failwith
           (sprintf "Fee must at least be %s"
              (Currency.Fee.to_formatted_string Flags.min_fee)) ;
       create_command ~debug ~keyfile ~fee ~nonce ~memo ~snapp_keyfile
         ~permissions
         ~current_auth:(Util.auth_of_string current_auth)))

let test_snapp_with_genesis_ledger =
  Command.(
    let open Let_syntax in
    Command.async
      ~summary:
        "Generate a trivial snapp transaction and genesis ledger with \
         verification key for testing"
      (let%map keyfile =
         Param.flag "--fee-payer-key"
           ~doc:
             "KEYFILE Private key file for the fee payer of the transaction \
              (should be in the genesis ledger)"
           Param.(required string)
       and snapp_keyfile =
         Param.flag "--snapp-account-key"
           ~doc:"KEYFILE Private key file to create a new snapp account"
           Param.(required string)
       and config_file =
         Param.flag "--config-file" ~aliases:[ "config-file" ]
           ~doc:
             "PATH path to a configuration file consisting the genesis ledger"
           Param.(required string)
       in
       test_snapp_with_genesis_ledger_main keyfile snapp_keyfile config_file))

let txn_commands =
  [ ("create-snapp-account", create_snapp_account)
  ; ("upgrade-snapp", upgrade_snapp)
  ; ("transfer-funds", transfer_funds)
  ; ("update-state", update_state)
  ; ("update-snapp-uri", update_snapp_uri)
  ; ("update-sequence-state", update_sequence_state)
  ; ("update-token-symbol", update_token_symbol)
  ; ("update-permissions", update_permissions)
  ; ("test-snapp-with-genesis-ledger", test_snapp_with_genesis_ledger)
  ]

let () =
  Command.run
    (Command.group ~summary:"Snapp test transaction"
       ~preserve_subcommand_order:() txn_commands)
