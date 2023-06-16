(** Testing
    -------
    Component:  Network pool
    Invocation: dune exec src/lib/network_pool/test/main.exe -- \
                  test '^indexed pool$'
    Subject:    Test the indexed pool.
 *)

open Core_kernel
open Mina_base
open Mina_numbers
open Mina_transaction
open Signature_lib
open Network_pool
open Indexed_pool
open For_tests

let test_keys = Array.init 10 ~f:(fun _ -> Keypair.create ())

let gen_cmd ?sign_type ?nonce () =
  User_command.Valid.Gen.payment_with_random_participants ~keys:test_keys
    ~max_amount:1000 ~fee_range:10 ?sign_type ?nonce ()
  |> Quickcheck.Generator.map
       ~f:Transaction_hash.User_command_with_valid_signature.create

let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

let constraint_constants = precomputed_values.constraint_constants

let consensus_constants = precomputed_values.consensus_constants

let logger = Logger.null ()

let time_controller = Block_time.Controller.basic ~logger

let empty = empty ~constraint_constants ~consensus_constants ~time_controller

let empty_invariants () = assert_invariants empty

let singleton_properties () =
  Quickcheck.test (gen_cmd ()) ~f:(fun cmd ->
      let pool = empty in
      let add_res =
        add_from_gossip_exn pool cmd Account_nonce.zero
          (Currency.Amount.of_nanomina_int_exn 500)
      in
      if
        Option.value_exn (currency_consumed ~constraint_constants cmd)
        |> Currency.Amount.to_nanomina_int > 500
      then
        match add_res with
        | Error (Insufficient_funds _) ->
            ()
        | _ ->
            failwith "should've returned insufficient_funds"
      else
        match add_res with
        | Ok (_, pool', dropped) ->
            assert_invariants pool' ;
            assert (Sequence.is_empty dropped) ;
            [%test_eq: int] (size pool') 1 ;
            [%test_eq:
              Transaction_hash.User_command_with_valid_signature.t option]
              (get_highest_fee pool') (Some cmd) ;
            let dropped', pool'' = remove_lowest_fee pool' in
            [%test_eq:
              Transaction_hash.User_command_with_valid_signature.t Sequence.t]
              dropped' (Sequence.singleton cmd) ;
            [%test_eq: t] ~equal pool pool''
        | _ ->
            failwith "should've succeeded" )

let sequential_adds_all_valid () =
  let gen :
      ( Mina_ledger.Ledger.init_state
      * Transaction_hash.User_command_with_valid_signature.t list )
      Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind ledger_init = Mina_ledger.Ledger.gen_initial_ledger_state in
    let%map cmds = User_command.Valid.Gen.sequence ledger_init in
    ( ledger_init
    , List.map ~f:Transaction_hash.User_command_with_valid_signature.create cmds
    )
  in
  let shrinker :
      ( Mina_ledger.Ledger.init_state
      * Transaction_hash.User_command_with_valid_signature.t list )
      Quickcheck.Shrinker.t =
    Quickcheck.Shrinker.create (fun (init_state, cmds) ->
        Sequence.singleton (init_state, List.take cmds (List.length cmds - 1)) )
  in
  Quickcheck.test gen ~trials:1000
    ~sexp_of:
      [%sexp_of:
        Mina_ledger.Ledger.init_state
        * Transaction_hash.User_command_with_valid_signature.t list]
    ~shrinker ~shrink_attempts:`Exhaustive ~seed:(`Deterministic "d")
    ~sizes:(Sequence.repeat 10) ~f:(fun (ledger_init, cmds) ->
      let account_init_states_seq = Array.to_sequence ledger_init in
      let balances = Hashtbl.create (module Public_key.Compressed) in
      let nonces = Hashtbl.create (module Public_key.Compressed) in
      Sequence.iter account_init_states_seq ~f:(fun (kp, balance, nonce, _) ->
          let compressed = Public_key.compress kp.public_key in
          Hashtbl.add_exn balances ~key:compressed ~data:balance ;
          Hashtbl.add_exn nonces ~key:compressed ~data:nonce ) ;
      let pool = ref empty in
      let rec go cmds_acc =
        match cmds_acc with
        | [] ->
            ()
        | cmd :: rest -> (
            let unchecked =
              Transaction_hash.User_command_with_valid_signature.command cmd
            in
            let account_id = User_command.fee_payer unchecked in
            let pk = Account_id.public_key account_id in
            let add_res =
              add_from_gossip_exn !pool cmd
                (Hashtbl.find_exn nonces pk)
                (Hashtbl.find_exn balances pk)
            in
            match add_res with
            | Ok (_, pool', dropped) ->
                [%test_eq:
                  Transaction_hash.User_command_with_valid_signature.t
                  Sequence.t] dropped Sequence.empty ;
                assert_invariants pool' ;
                pool := pool' ;
                go rest
            | Error (Invalid_nonce (`Expected want, got)) ->
                failwithf
                  !"Bad nonce. Expected: %{sexp: Account.Nonce.t}. Got: \
                    %{sexp: Account.Nonce.t}"
                  want got ()
            | Error (Invalid_nonce (`Between (low, high), got)) ->
                failwithf
                  !"Bad nonce. Expected between %{sexp: Account.Nonce.t} and \
                    %{sexp:Account.Nonce.t}. Got: %{sexp: Account.Nonce.t}"
                  low high got ()
            | Error (Insufficient_funds (`Balance bal, amt)) ->
                failwithf
                  !"Insufficient funds. Balance: %{sexp: Currency.Amount.t}. \
                    Amount: %{sexp: Currency.Amount.t}"
                  bal amt ()
            | Error (Insufficient_replace_fee (`Replace_fee rfee, fee)) ->
                failwithf
                  !"Insufficient fee for replacement. Needed at least %{sexp: \
                    Currency.Fee.t} but got %{sexp:Currency.Fee.t}."
                  rfee fee ()
            | Error Overflow ->
                failwith "Overflow."
            | Error Bad_token ->
                failwith "Token is incompatible with the command."
            | Error (Unwanted_fee_token fee_token) ->
                failwithf
                  !"Bad fee token. The fees are paid in token %{sexp: \
                    Token_id.t}, which we are not accepting fees in."
                  fee_token ()
            | Error
                (Expired
                  ( `Valid_until valid_until
                  , `Global_slot_since_genesis global_slot_since_genesis ) ) ->
                failwithf
                  !"Expired user command. Current global slot is \
                    %{sexp:Mina_numbers.Global_slot_since_genesis.t} but user \
                    command is only valid until \
                    %{sexp:Mina_numbers.Global_slot_since_genesis.t}"
                  global_slot_since_genesis valid_until () )
      in
      go cmds )

let replacement () =
  let modify_payment (c : User_command.t) ~sender ~common:fc ~body:fb =
    let modified_payload : Signed_command.Payload.t =
      match c with
      | Signed_command
          { payload = { body = Payment payment_payload; common }; _ } ->
          { common = fc common
          ; body = Signed_command.Payload.Body.Payment (fb payment_payload)
          }
      | _ ->
          failwith "generated user command that wasn't a payment"
    in
    Signed_command (Signed_command.For_tests.fake_sign sender modified_payload)
    |> Transaction_hash.User_command_with_valid_signature.create
  in
  let gen :
      ( Account_nonce.t
      * Currency.Amount.t
      * Transaction_hash.User_command_with_valid_signature.t list
      * Transaction_hash.User_command_with_valid_signature.t )
      Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind sender_index = Int.gen_incl 0 9 in
    let sender = test_keys.(sender_index) in
    let%bind init_nonce =
      Quickcheck.Generator.map ~f:Account_nonce.of_int @@ Int.gen_incl 0 1000
    in
    let init_balance = Currency.Amount.of_mina_int_exn 100_000 in
    let%bind size = Quickcheck.Generator.size in
    let%bind amounts =
      Quickcheck.Generator.map ~f:Array.of_list
      @@ Quickcheck_lib.gen_division_currency init_balance (size + 1)
    in
    let rec go current_nonce current_balance n =
      if n > 0 then
        let%bind cmd =
          let key_gen =
            Quickcheck.Generator.tuple2 (return sender)
              (Quickcheck_lib.of_array test_keys)
          in
          Mina_generators.User_command_generators.payment ~sign_type:`Fake
            ~key_gen ~nonce:current_nonce ~max_amount:1 ~fee_range:0 ()
        in
        let cmd_currency = amounts.(n - 1) in
        let%bind fee =
          Currency.Amount.(
            gen_incl zero (min (of_nanomina_int_exn 10) cmd_currency))
        in
        let amount = Option.value_exn Currency.Amount.(cmd_currency - fee) in
        let cmd' =
          modify_payment cmd ~sender
            ~common:(fun c -> { c with fee = Currency.Amount.to_fee fee })
            ~body:(fun b -> { b with amount })
        in
        let consumed =
          Option.value_exn (currency_consumed ~constraint_constants cmd')
        in
        let%map rest =
          go
            (Account_nonce.succ current_nonce)
            (Option.value_exn Currency.Amount.(current_balance - consumed))
            (n - 1)
        in
        cmd' :: rest
      else return []
    in
    let%bind setup_cmds = go init_nonce init_balance (size + 1) in
    let init_nonce_int = Account.Nonce.to_int init_nonce in
    let%bind replaced_nonce =
      Int.gen_incl init_nonce_int (init_nonce_int + List.length setup_cmds - 1)
    in
    let%map replace_cmd_skeleton =
      let key_gen =
        Quickcheck.Generator.tuple2 (return sender)
          (Quickcheck_lib.of_array test_keys)
      in
      Mina_generators.User_command_generators.payment ~sign_type:`Fake ~key_gen
        ~nonce:(Account_nonce.of_int replaced_nonce)
        ~max_amount:(Currency.Amount.to_nanomina_int init_balance)
        ~fee_range:0 ()
    in
    let replace_cmd =
      modify_payment replace_cmd_skeleton ~sender ~body:Fn.id ~common:(fun c ->
          { c with fee = Currency.Fee.of_mina_int_exn (10 + (5 * (size + 1))) } )
    in
    (init_nonce, init_balance, setup_cmds, replace_cmd)
  in
  Quickcheck.test ~trials:20 gen
    ~sexp_of:
      [%sexp_of:
        Account_nonce.t
        * Currency.Amount.t
        * Transaction_hash.User_command_with_valid_signature.t list
        * Transaction_hash.User_command_with_valid_signature.t]
    ~f:(fun (init_nonce, init_balance, setup_cmds, replace_cmd) ->
      let t =
        List.fold_left setup_cmds ~init:empty ~f:(fun t cmd ->
            match add_from_gossip_exn t cmd init_nonce init_balance with
            | Ok (_, t', removed) ->
                [%test_eq:
                  Transaction_hash.User_command_with_valid_signature.t
                  Sequence.t] removed Sequence.empty ;
                t'
            | _ ->
                failwith
                @@ sprintf
                     !"adding command %{sexp: \
                       Transaction_hash.User_command_with_valid_signature.t} \
                       failed"
                     cmd )
      in
      let replaced_idx, _ =
        let replace_nonce =
          replace_cmd
          |> Transaction_hash.User_command_with_valid_signature.command
          |> User_command.applicable_at_nonce
        in
        List.findi setup_cmds ~f:(fun _i cmd ->
            let cmd_nonce =
              cmd |> Transaction_hash.User_command_with_valid_signature.command
              |> User_command.applicable_at_nonce
            in
            Account_nonce.compare replace_nonce cmd_nonce <= 0 )
        |> Option.value_exn
      in
      let currency_consumed_pre_replace =
        List.fold_left
          (List.take setup_cmds (replaced_idx + 1))
          ~init:Currency.Amount.zero
          ~f:(fun consumed_so_far cmd ->
            Option.value_exn
              Option.(
                currency_consumed ~constraint_constants cmd
                >>= fun consumed -> Currency.Amount.(consumed + consumed_so_far))
            )
      in
      assert (Currency.Amount.(currency_consumed_pre_replace <= init_balance)) ;
      let currency_consumed_post_replace =
        Option.value_exn
          (let open Option.Let_syntax in
          let%bind replaced_currency_consumed =
            currency_consumed ~constraint_constants
            @@ List.nth_exn setup_cmds replaced_idx
          in
          let%bind replacer_currency_consumed =
            currency_consumed ~constraint_constants replace_cmd
          in
          let%bind a =
            Currency.Amount.(
              currency_consumed_pre_replace - replaced_currency_consumed)
          in
          Currency.Amount.(a + replacer_currency_consumed))
      in
      let add_res = add_from_gossip_exn t replace_cmd init_nonce init_balance in
      if Currency.Amount.(currency_consumed_post_replace <= init_balance) then
        match add_res with
        | Ok (_, t', dropped) ->
            assert (not (Sequence.is_empty dropped)) ;
            assert_invariants t'
        | Error _ ->
            failwith "adding command failed"
      else
        match add_res with
        | Error (Insufficient_funds _) ->
            ()
        | _ ->
            failwith "should've returned insufficient_funds" )

let remove_lowest_fee () =
  let cmds =
    gen_cmd () |> Quickcheck.random_sequence |> Fn.flip Sequence.take 4
    |> Sequence.to_list
  in
  let compare cmd0 cmd1 : int =
    let open Transaction_hash.User_command_with_valid_signature in
    Currency.Fee_rate.compare
      (User_command.fee_per_wu @@ command cmd0)
      (User_command.fee_per_wu @@ command cmd1)
  in
  let cmds_sorted_by_fee_per_wu = List.sort ~compare cmds in
  let cmd_lowest_fee, commands_to_keep =
    ( List.hd_exn cmds_sorted_by_fee_per_wu
    , List.tl_exn cmds_sorted_by_fee_per_wu )
  in
  let insert_cmd pool cmd =
    add_from_gossip_exn pool cmd Account_nonce.zero
      (Currency.Amount.of_mina_int_exn 5)
    |> Result.ok |> Option.value_exn
    |> fun (_, pool, _) -> pool
  in
  let cmd_equal = Transaction_hash.User_command_with_valid_signature.equal in
  let removed, pool =
    List.fold_left cmds ~init:empty ~f:insert_cmd |> remove_lowest_fee
  in
  (* check that the lowest fee per wu command is returned *)
  assert (Sequence.(equal cmd_equal removed @@ return cmd_lowest_fee))
  |> fun () ->
  (* check that the lowest fee per wu command is removed from
     applicable_by_fee *)
  applicable_by_fee pool |> Map.data
  |> List.concat_map ~f:Set.to_list
  |> fun applicable_by_fee_cmds ->
  assert (List.(equal cmd_equal applicable_by_fee_cmds commands_to_keep))
  |> fun () ->
  (* check that the lowest fee per wu command is removed from
     all_by_fee *)
  applicable_by_fee pool |> Map.data
  |> List.concat_map ~f:Set.to_list
  |> fun all_by_fee_cmds ->
  assert (List.(equal cmd_equal all_by_fee_cmds commands_to_keep))

let find_highest_fee () =
  let cmds =
    gen_cmd () |> Quickcheck.random_sequence |> Fn.flip Sequence.take 4
    |> Sequence.to_list
  in
  let compare cmd0 cmd1 : int =
    let open Transaction_hash.User_command_with_valid_signature in
    Currency.Fee_rate.compare
      (User_command.fee_per_wu @@ command cmd0)
      (User_command.fee_per_wu @@ command cmd1)
  in
  let max_by_fee_per_wu = List.max_elt ~compare cmds |> Option.value_exn in
  let insert_cmd pool cmd =
    add_from_gossip_exn pool cmd Account_nonce.zero
      (Currency.Amount.of_mina_int_exn 5)
    |> Result.ok |> Option.value_exn
    |> fun (_, pool, _) -> pool
  in
  let pool = List.fold_left cmds ~init:empty ~f:insert_cmd in
  let cmd_equal = Transaction_hash.User_command_with_valid_signature.equal in
  get_highest_fee pool |> Option.value_exn
  |> fun highest_fee -> assert (cmd_equal highest_fee max_by_fee_per_wu)

let dummy_state_view =
  let state_body =
    let consensus_constants =
      let genesis_constants = Genesis_constants.for_unit_tests in
      Consensus.Constants.create ~constraint_constants
        ~protocol_constants:genesis_constants.protocol
    in
    let compile_time_genesis =
      (*not using Precomputed_values.for_unit_test because of dependency cycle*)
      Mina_state.Genesis_protocol_state.t
        ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
        ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
        ~genesis_body_reference:Staged_ledger_diff.genesis_body_reference
        ~constraint_constants ~consensus_constants
    in
    compile_time_genesis.data |> Mina_state.Protocol_state.body
  in
  { (Mina_state.Protocol_state.Body.view state_body) with
    global_slot_since_genesis = Mina_numbers.Global_slot_since_genesis.zero
  }

let add_to_pool ~nonce ~balance pool cmd =
  let _, pool', dropped =
    add_from_gossip_exn pool cmd nonce balance
    |> Result.map_error ~f:(Fn.compose Sexp.to_string Command_error.sexp_of_t)
    |> Result.ok_or_failwith
  in
  [%test_eq: Transaction_hash.User_command_with_valid_signature.t Sequence.t]
    dropped Sequence.empty ;
  assert_invariants pool' ;
  pool'

let init_permissionless_ledger ledger account_info =
  let open Currency in
  let open Mina_ledger.Ledger.Ledger_inner in
  List.iter account_info ~f:(fun (public_key, amount) ->
      let account_id =
        Account_id.create (Public_key.compress public_key) Token_id.default
      in
      let balance =
        Balance.of_nanomina_int_exn @@ Amount.to_nanomina_int amount
      in
      let _tag, account, location =
        Or_error.ok_exn (get_or_create ledger account_id)
      in
      set ledger location
        { account with balance; permissions = Permissions.empty } )

let apply_to_ledger ledger cmd =
  match Transaction_hash.User_command_with_valid_signature.command cmd with
  | User_command.Signed_command c ->
      let (`If_this_is_used_it_should_have_a_comment_justifying_it v) =
        Signed_command.to_valid_unsafe c
      in
      ignore
        ( Mina_ledger.Ledger.apply_user_command ~constraint_constants
            ~txn_global_slot:Mina_numbers.Global_slot_since_genesis.zero ledger
            v
          |> Or_error.ok_exn
          : Mina_transaction_logic.Transaction_applied.Signed_command_applied.t
          )
  | User_command.Zkapp_command p -> (
      let applied, _ =
        Mina_ledger.Ledger.apply_zkapp_command_unchecked ~constraint_constants
          ~global_slot:dummy_state_view.global_slot_since_genesis
          ~state_view:dummy_state_view ledger p
        |> Or_error.ok_exn
      in
      match With_status.status applied.command with
      | Transaction_status.Applied ->
          ()
      | Transaction_status.Failed failure ->
          failwithf "failed to apply zkapp_command transaction to ledger: [%s]"
            ( String.concat ~sep:", "
            @@ List.bind
                 ~f:(List.map ~f:Transaction_status.Failure.to_string)
                 failure )
            () )

let commit_to_pool ledger pool cmd expected_drops =
  apply_to_ledger ledger cmd ;
  let accounts_to_check =
    Transaction_hash.User_command_with_valid_signature.command cmd
    |> User_command.accounts_referenced |> Account_id.Set.of_list
  in
  let pool, dropped =
    revalidate pool ~logger (`Subset accounts_to_check) (fun sender ->
        match Mina_ledger.Ledger.location_of_account ledger sender with
        | None ->
            Account.empty
        | Some loc ->
            Option.value_exn
              ~message:"Somehow a public key has a location but no account"
              (Mina_ledger.Ledger.get ledger loc) )
  in
  let lower =
    List.map ~f:Transaction_hash.User_command_with_valid_signature.hash
  in
  [%test_eq: Transaction_hash.t list]
    (lower (Sequence.to_list dropped))
    (lower expected_drops) ;
  assert_invariants pool ;
  pool

let make_zkapp_command_payment ~(sender : Keypair.t) ~(receiver : Keypair.t)
    ~double_increment_sender ~increment_receiver ~amount ~fee nonce_int =
  let open Currency in
  let nonce = Account.Nonce.of_int nonce_int in
  let sender_pk = Public_key.compress sender.public_key in
  let receiver_pk = Public_key.compress receiver.public_key in
  let zkapp_command_wire : Zkapp_command.Stable.Latest.Wire.t =
    { fee_payer =
        { Account_update.Fee_payer.body =
            { public_key = sender_pk; fee; nonce; valid_until = None }
            (* Real signature added in below *)
        ; authorization = Signature.dummy
        }
    ; account_updates =
        Zkapp_command.Call_forest.of_account_updates
          ~account_update_depth:(Fn.const 0)
          [ { Account_update.body =
                { public_key = sender_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.(negate @@ of_unsigned amount)
                ; increment_nonce = double_increment_sender
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account =
                        Account_update.Account_precondition.Nonce
                          (Account.Nonce.succ nonce)
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; use_full_commitment = not double_increment_sender
                ; implicit_account_creation_fee = false
                ; authorization_kind = None_given
                }
            ; authorization = None_given
            }
          ; { Account_update.body =
                { public_key = receiver_pk
                ; update = Account_update.Update.noop
                ; token_id = Token_id.default
                ; balance_change = Amount.Signed.of_unsigned amount
                ; increment_nonce = increment_receiver
                ; events = []
                ; actions = []
                ; call_data = Snark_params.Tick.Field.zero
                ; preconditions =
                    { Account_update.Preconditions.network =
                        Zkapp_precondition.Protocol_state.accept
                    ; account = Account_update.Account_precondition.Accept
                    ; valid_while = Ignore
                    }
                ; may_use_token = No
                ; implicit_account_creation_fee = false
                ; use_full_commitment = not increment_receiver
                ; authorization_kind = None_given
                }
            ; authorization = None_given
            }
          ]
    ; memo = Signed_command_memo.empty
    }
  in
  let zkapp_command = Zkapp_command.of_wire zkapp_command_wire in
  (* We skip signing the commitment and updating the authorization as it is not necessary to have a valid transaction for these tests. *)
  let (`If_this_is_used_it_should_have_a_comment_justifying_it cmd) =
    User_command.to_valid_unsafe (User_command.Zkapp_command zkapp_command)
  in
  Transaction_hash.User_command_with_valid_signature.create cmd

let support_for_zkapp_command_commands () =
  let open Currency in
  let fee = Currency.Fee.minimum_user_command_fee in
  let amount = Amount.of_nanomina_int_exn @@ Fee.to_nanomina_int fee in
  let balance = Option.value_exn (Amount.scale amount 100) in
  let kp1 =
    Quickcheck.random_value ~seed:(`Deterministic "apple") Keypair.gen
  in
  let kp2 =
    Quickcheck.random_value ~seed:(`Deterministic "orange") Keypair.gen
  in
  let add_cmd = add_to_pool ~nonce:Account_nonce.zero ~balance in
  let make_cmd =
    make_zkapp_command_payment ~sender:kp1 ~receiver:kp2
      ~increment_receiver:false ~amount ~fee
  in
  Mina_ledger.Ledger.with_ledger ~depth:4 ~f:(fun ledger ->
      init_permissionless_ledger ledger
        [ (kp1.public_key, balance); (kp2.public_key, Amount.zero) ] ;
      let commit = commit_to_pool ledger in
      let cmd1 = make_cmd ~double_increment_sender:false 0 in
      let cmd2 = make_cmd ~double_increment_sender:false 1 in
      let cmd3 = make_cmd ~double_increment_sender:false 2 in
      let cmd4 = make_cmd ~double_increment_sender:false 3 in
      (* used to break the sequence *)
      let cmd3' = make_cmd ~double_increment_sender:true 2 in
      let pool =
        List.fold_left [ cmd1; cmd2; cmd3; cmd4 ] ~init:empty ~f:add_cmd
      in
      let pool = commit pool cmd1 [ cmd1 ] in
      let pool = commit pool cmd2 [ cmd2 ] in
      let _pool = commit pool cmd3' [ cmd3; cmd4 ] in
      () )

let nonce_increment_side_effects () =
  let open Currency in
  let fee = Currency.Fee.minimum_user_command_fee in
  let amount = Amount.of_nanomina_int_exn @@ Fee.to_nanomina_int fee in
  let balance = Option.value_exn (Amount.scale amount 100) in
  let kp1 =
    Quickcheck.random_value ~seed:(`Deterministic "apple") Keypair.gen
  in
  let kp2 =
    Quickcheck.random_value ~seed:(`Deterministic "orange") Keypair.gen
  in
  let add_cmd = add_to_pool ~nonce:Account_nonce.zero ~balance in
  let make_cmd = make_zkapp_command_payment ~amount ~fee in
  Mina_ledger.Ledger.with_ledger ~depth:4 ~f:(fun ledger ->
      init_permissionless_ledger ledger
        [ (kp1.public_key, balance); (kp2.public_key, balance) ] ;
      let kp1_cmd1 =
        make_cmd ~sender:kp1 ~receiver:kp2 ~double_increment_sender:false
          ~increment_receiver:true 0
      in
      let kp2_cmd1 =
        make_cmd ~sender:kp2 ~receiver:kp1 ~double_increment_sender:false
          ~increment_receiver:false 0
      in
      let kp2_cmd2 =
        make_cmd ~sender:kp2 ~receiver:kp1 ~double_increment_sender:false
          ~increment_receiver:false 1
      in
      let pool =
        List.fold_left [ kp1_cmd1; kp2_cmd1; kp2_cmd2 ] ~init:empty ~f:add_cmd
      in
      let _pool = commit_to_pool ledger pool kp1_cmd1 [ kp2_cmd1; kp1_cmd1 ] in
      () )

let nonce_invariant_violation () =
  let open Currency in
  let fee = Currency.Fee.minimum_user_command_fee in
  let amount = Amount.of_nanomina_int_exn @@ Fee.to_nanomina_int fee in
  let balance = Option.value_exn (Amount.scale amount 100) in
  let kp1 =
    Quickcheck.random_value ~seed:(`Deterministic "apple") Keypair.gen
  in
  let kp2 =
    Quickcheck.random_value ~seed:(`Deterministic "orange") Keypair.gen
  in
  let add_cmd = add_to_pool ~nonce:Account_nonce.zero ~balance in
  let make_cmd =
    make_zkapp_command_payment ~sender:kp1 ~receiver:kp2
      ~double_increment_sender:false ~increment_receiver:false ~amount ~fee
  in
  Mina_ledger.Ledger.with_ledger ~depth:4 ~f:(fun ledger ->
      init_permissionless_ledger ledger
        [ (kp1.public_key, balance); (kp2.public_key, Amount.zero) ] ;
      let cmd1 = make_cmd 0 in
      let cmd2 = make_cmd 1 in
      let pool = List.fold_left [ cmd1; cmd2 ] ~init:empty ~f:add_cmd in
      apply_to_ledger ledger cmd1 ;
      let _pool = commit_to_pool ledger pool cmd2 [ cmd1; cmd2 ] in
      () )
