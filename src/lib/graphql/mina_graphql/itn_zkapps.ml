open Core
open Async
open Mina_base

let deploy_zkapps ~scheduler_tbl ~mina ~ledger ~deployment_fee ~max_cost
    ~init_balance ~(fee_payer_array : Signature_lib.Keypair.t Array.t)
    ~constraint_constants ~logger ~memo_prefix ~wait_span ~stop_signal
    ~stop_time ~uuid keypairs =
  O1trace.thread "itn_deploy_zkapps"
  @@ fun () ->
  let fee_payer_accounts =
    Array.map fee_payer_array ~f:(fun key -> Utils.account_of_kp key ledger)
  in
  let fee_payer_nonces =
    Array.map fee_payer_accounts ~f:(fun account -> ref account.nonce)
  in
  let num_fee_payers = Array.length fee_payer_array in
  let finished () =
    if Time.(now () >= stop_time) then (
      [%log info]
        "Scheduled zkapp commands with handle %s has expired, stop deployment \
         of zkapp accounts"
        (Uuid.to_string uuid) ;
      Uuid.Table.remove scheduler_tbl uuid ;
      true )
    else if Ivar.is_full stop_signal then (
      [%log info]
        "Scheduled zkapp commands with handle %s received stop signal, stop \
         deployment of zkapp accounts"
        (Uuid.to_string uuid) ;
      Uuid.Table.remove scheduler_tbl uuid ;
      true )
    else false
  in
  Deferred.List.iteri keypairs ~f:(fun i kp ->
      let ndx = i mod num_fee_payers in
      if finished () then Deferred.unit
      else
        let fee_payer_keypair = fee_payer_array.(ndx) in
        let memo = sprintf "%s-%d" memo_prefix i in
        let spec =
          { Transaction_snark.For_tests.Deploy_snapp_spec.sender =
              (fee_payer_keypair, !(fee_payer_nonces.(ndx)))
          ; fee = deployment_fee
          ; fee_payer = None
          ; amount = init_balance
          ; zkapp_account_keypairs = [ kp ]
          ; memo = Signed_command_memo.create_from_string_exn memo
          ; new_zkapp_account = true
          ; snapp_update = Account_update.Update.dummy
          ; preconditions = None
          ; authorization_kind = Account_update.Authorization_kind.Signature
          }
        in
        let zkapp_command =
          Transaction_snark.For_tests.deploy_snapp ~constraint_constants
            ~signature_kind:Testnet
            ~permissions:
              ( if max_cost then
                { Permissions.user_default with
                  set_verification_key =
                    ( Permissions.Auth_required.Proof
                    , Mina_numbers.Txn_version.current )
                ; edit_state = Permissions.Auth_required.Proof
                ; edit_action_state = Proof
                }
              else Permissions.user_default )
            spec
        in
        let%bind zkapp_command = zkapp_command in
        let%bind () = after wait_span in
        Deferred.repeat_until_finished ()
        @@ fun () ->
        if finished () then Deferred.return (`Finished ())
        else
          (* TODO create without hash accumulation and remove read_all_proofs_from_disk call *)
          match%bind
            Zkapps.send_zkapp_command mina
              (Zkapp_command.read_all_proofs_from_disk zkapp_command)
          with
          | Ok _ ->
              fee_payer_nonces.(ndx) :=
                Account.Nonce.succ !(fee_payer_nonces.(ndx)) ;
              [%log info]
                "Successfully submitted zkApp command that creates a zkApp \
                 account"
                ~metadata:
                  [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command) ] ;
              Deferred.return (`Finished ())
          | Error err ->
              [%log info] "Failed to setup a zkApp account, try again"
                ~metadata:
                  [ ("zkapp_command", Zkapp_command.to_yojson zkapp_command)
                  ; ("error", `String err)
                  ] ;
              let%bind () = after wait_span in
              Deferred.return (`Repeat ()) )

let is_zkapp_deployed ledger kp =
  try Option.is_some (Utils.account_of_kp kp ledger).zkapp with _ -> false

let all_zkapps_deployed ~ledger (keypairs : Signature_lib.Keypair.t list) =
  List.map keypairs ~f:(is_zkapp_deployed ledger) |> List.for_all ~f:Fn.id

let rec wait_until_zkapps_deployed ?(deployed = false) ~scheduler_tbl ~mina
    ~ledger ~deployment_fee ~max_cost ~init_balance
    ~(fee_payer_array : Signature_lib.Keypair.t Array.t) ~constraint_constants
    ~logger ~uuid ~stop_signal ~stop_time ~memo_prefix ~wait_span
    (keypairs : Signature_lib.Keypair.t list) =
  if Time.( >= ) (Time.now ()) stop_time then (
    [%log info] "Scheduled zkApp commands with handle %s has expired"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    return None )
  else if Ivar.is_full stop_signal then (
    [%log info] "Stopping scheduled zkApp commands with handle %s"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    return None )
  else if all_zkapps_deployed ~ledger keypairs then (
    [%log info] "All zkApp accounts are deployed" ;
    return (Some ledger) )
  else
    let%bind () =
      if not deployed then (
        [%log info] "Start deploying zkApp accounts" ;
        deploy_zkapps ~scheduler_tbl ~mina ~ledger ~deployment_fee ~max_cost
          ~init_balance ~fee_payer_array ~constraint_constants ~logger
          ~memo_prefix ~wait_span ~stop_signal ~stop_time ~uuid keypairs )
      else return ()
    in
    [%log debug]
      "Some deployed zkApp accounts weren't found in the best tip ledger, \
       trying again" ;
    let%bind () =
      (* Checking three times per block window to avoid unnecessary waiting after the block is created *)
      Async.after
        (Time.Span.of_ms
           (Float.of_int constraint_constants.block_window_duration_ms /. 3.0) )
    in
    let ledger =
      Utils.get_ledger_and_breadcrumb mina
      |> Option.value_map ~default:ledger ~f:(fun (new_ledger, _) ->
             new_ledger )
    in
    wait_until_zkapps_deployed ~scheduler_tbl ~deployed:true ~mina ~ledger
      ~deployment_fee ~max_cost ~init_balance ~fee_payer_array
      ~constraint_constants ~logger ~uuid ~stop_signal ~stop_time ~memo_prefix
      ~wait_span keypairs

let insert_account_queue ~account_queue ~account_queue_size ~account_state_tbl
    id =
  let a = Account_id.Table.find_and_remove account_state_tbl id in
  Queue.enqueue account_queue (Option.value_exn a) ;
  if Queue.length account_queue > account_queue_size then
    let a, role = Queue.dequeue_exn account_queue in
    Account_id.Table.add_exn account_state_tbl ~key:(Account.identifier a)
      ~data:(a, role)
  else ()

let send_zkapps ~(genesis_constants : Genesis_constants.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t)
    ~fee_payer_array ~tm_end ~scheduler_tbl ~uuid ~keymap ~unused_pks
    ~stop_signal ~mina ~zkapp_command_details ~wait_span ~logger
    ~account_state_tbl init_tm_next init_counter =
  let wait_span_ms = Time.Span.to_ms wait_span |> int_of_float in
  let repeat tm_next counter =
    let%map () = Async_unix.at tm_next in
    let open Time in
    let next_tm_next = add tm_next wait_span in
    let now = now () in
    let next_tm_next =
      if next_tm_next <= now then
        (* This is done to ensure there is no effect of transactions coming out one by one,
           let there be some pause under any cricumstances *)
        let span = diff now next_tm_next |> Span.to_ms in
        let additive =
          wait_span_ms - (int_of_float span % wait_span_ms)
          |> float_of_int |> Span.of_ms
        in
        add now additive
      else next_tm_next
    in
    `Repeat (next_tm_next, counter + 1)
  in
  let `VK vk, `Prover prover =
    Transaction_snark.For_tests.create_trivial_snapp ()
  in
  let%bind.Deferred vk = vk in
  let cache = ref Mina_base.Zkapp_statement.Map.empty in
  let account_queue = Queue.create () in
  let num_fee_payers = Array.length fee_payer_array in
  Deferred.repeat_until_finished (init_tm_next, init_counter)
  @@ fun (tm_next, counter) ->
  let ndx = counter mod num_fee_payers in
  if Time.( >= ) (Time.now ()) tm_end then (
    [%log info] "Scheduled zkApp commands with handle %s has expired"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.return (`Finished ()) )
  else if Ivar.is_full stop_signal then (
    [%log info] "Stopping scheduled zkApp commands with handle %s"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.return (`Finished ()) )
  else
    let fee_payer : Signature_lib.Keypair.t = fee_payer_array.(ndx) in
    let zkapp_dummy_opt_res =
      O1trace.sync_thread "itn_generate_dummy_zkapp"
      @@ fun () ->
      match Utils.get_ledger_and_breadcrumb mina with
      | None ->
          [%log info]
            "Failed to fetch the best tip ledger, skip this round, we will try \
             again at $time"
            ~metadata:
              [ ("time", `String (Time.to_string_fix_proto `Local tm_next)) ] ;
          Result.return None
      | Some (ledger, _) ->
          let number_of_accounts_generated =
            let f = function _, `New_account -> true | _ -> false in
            Account_id.Table.count ~f account_state_tbl
            + Queue.count ~f account_queue
          in
          let generate_new_accounts =
            number_of_accounts_generated
            < zkapp_command_details
                .Types.Input.Itn.ZkappCommandsDetails.num_new_accounts
          in
          let memo =
            sprintf "%s-%d" zkapp_command_details.memo_prefix counter
          in
          let fee_payer_pk =
            Signature_lib.Public_key.compress fee_payer.public_key
          in
          Result.try_with
          @@ fun () ->
          Option.some
          @@ Quickcheck.Generator.generate
               ( if zkapp_command_details.max_cost then
                 Mina_generators.Zkapp_command_generators
                 .gen_max_cost_zkapp_command_from ~memo
                   ~fee_range:
                     ( zkapp_command_details.min_fee
                     , zkapp_command_details.max_fee )
                   ~fee_payer_pk ~account_state_tbl ~vk
                   ~genesis_constants:
                     (Mina_lib.config mina).precomputed_values.genesis_constants
                   ()
               else
                 Mina_generators.Zkapp_command_generators.gen_zkapp_command_from
                   ~memo
                   ?max_account_updates:
                     zkapp_command_details.max_account_updates
                   ~no_account_precondition:
                     zkapp_command_details.no_precondition
                   ~fee_range:
                     ( zkapp_command_details.min_fee
                     , zkapp_command_details.max_fee )
                   ~balance_change_range:
                     zkapp_command_details.balance_change_range
                   ~ignore_sequence_events_precond:true ~no_token_accounts:true
                   ~limited:true ~fee_payer_keypair:fee_payer ~keymap
                   ~account_state_tbl ~generate_new_accounts ~ledger ~vk
                   ~available_public_keys:unused_pks ~genesis_constants
                   ~constraint_constants () )
               ~size:1
               ~random:(Splittable_random.State.create Random.State.default)
    in
    match zkapp_dummy_opt_res with
    | Error e ->
        [%log error]
          "Error $error creating zkapp transaction, stopping handle %s"
          (Uuid.to_string uuid)
          ~metadata:[ ("error", Error_json.error_to_yojson @@ Error.of_exn e) ] ;
        Deferred.return (`Finished ())
    | Ok None ->
        repeat tm_next counter
    | Ok (Some zkapp_dummy) ->
        let accounts = Zkapp_command.accounts_referenced zkapp_dummy in
        List.iter accounts
          ~f:
            (insert_account_queue ~account_queue
               ~account_queue_size:zkapp_command_details.account_queue_size
               ~account_state_tbl ) ;
        let%bind zkapp_command =
          O1trace.thread "itn_replace_zkapp_auth"
          @@ fun () ->
          (* Use cache for max cost zkapp commands *)
          if zkapp_command_details.max_cost then
            Mina_generators.Zkapp_command_generators
            .replace_proof_authorizations_for_max_cost ~cache ~prover ~keymap
              zkapp_dummy
            >>= Zkapp_command_builder.replace_authorizations ~keymap
          else
            Zkapp_command_builder.replace_authorizations ~prover ~keymap
              zkapp_dummy
        in
        let%bind () =
          O1trace.thread "itn_send_zkapp"
          @@ fun () ->
          (* TODO create without hash accumulation and remove read_all_proofs_from_disk call *)
          match%map
            Zkapps.send_zkapp_command mina
              (Zkapp_command.read_all_proofs_from_disk zkapp_command)
          with
          | Ok _ ->
              [%log info] "Sent out zkApp with fee payer's summary $summary"
                ~metadata:
                  [ ( "summary"
                    , User_command.fee_payer_summary_json
                        (Zkapp_command zkapp_command) )
                  ]
          | Error e ->
              [%log info] "Failed to send out zkApp command, see $error"
                ~metadata:[ ("error", `String e) ]
        in
        repeat tm_next counter

(* ----------------------------------------------------------------------------
   Non-default (custom) token load.

   When [nonDefaultToken] is requested we don't generate arbitrary default-token
   zkApp commands. Instead we stand up a single custom token once (an [owner]
   account that owns the token plus a fixed pool of [holders] minted an initial
   balance) and then, for the duration of the run, send commands that transfer
   that token between the holders, periodically re-minting so no holder runs dry.

   The command shapes mirror the (ledger-validated) zkapp_tokens unit test:
   a token op nests the holder account updates under the owner account update,
   with [may_use_token = Parents_own_token], so the owner authorizes use of its
   token. All updates use signature authorization, filled in afterwards by
   [Zkapp_command_builder.replace_authorizations]. A transfer nets to zero in the
   custom token (and in MINA), so it conserves balances; a mint is authorized by
   the owner. Account-creation fees (paid in MINA) are covered by an explicit
   negative MINA balance change on the funder/owner. *)

type custom_token =
  { owner : Signature_lib.Keypair.t
  ; token_id : Token_id.t
  ; holders : Signature_lib.Keypair.t array
  ; balances : int array
        (** tracked custom-token balance per holder, nanomina *)
  ; initial_mint : int
  ; transfer_cap : int
  ; mint_period : int
  }

let num_token_holders = 8

(* a large initial balance with small transfers means holders practically never
   run dry within a run; the periodic re-mint covers arbitrarily long runs *)
let initial_token_mint = 1_000_000_000_000

let token_transfer_cap = 1_000_000

let token_mint_period = 50

let create_custom_token ~(owner : Signature_lib.Keypair.t) : custom_token =
  let holders =
    Array.init num_token_holders ~f:(fun _ -> Signature_lib.Keypair.create ())
  in
  let owner_pk = Signature_lib.Public_key.compress owner.public_key in
  let token_id =
    Account_id.derive_token_id
      ~owner:(Account_id.create owner_pk Token_id.default)
  in
  { owner
  ; token_id
  ; holders
  ; balances = Array.create ~len:num_token_holders 0
  ; initial_mint = initial_token_mint
  ; transfer_cap = token_transfer_cap
  ; mint_period = token_mint_period
  }

(* owner + holder private keys must be in the keymap so signatures can be filled *)
let token_keypairs (ct : custom_token) = ct.owner :: Array.to_list ct.holders

let gen_fee ~(zkapp_command_details : Types.Input.Itn.ZkappCommandsDetails.input)
    =
  let lo = Currency.Fee.to_nanomina_int zkapp_command_details.min_fee in
  let hi = Currency.Fee.to_nanomina_int zkapp_command_details.max_fee in
  if hi <= lo then lo else lo + Random.int (hi - lo + 1)

let account_creation_fee
    (constraint_constants : Genesis_constants.Constraint_constants.t) =
  Currency.Fee.to_nanomina_int constraint_constants.account_creation_fee

(* fund + create the token owner (the create-token step of the unit test):
   [funder] supplies the MINA, [owner] is created and seeded with enough MINA to
   later pay the holders' account-creation fees *)
let build_owner_command ~constraint_constants ~fee ~fee_payer_pk
    ~fee_payer_nonce ~(funder : Signature_lib.Keypair.t)
    ~(owner : Signature_lib.Keypair.t) ~owner_seed =
  let open Zkapp_command_builder in
  let creation_fee = account_creation_fee constraint_constants in
  mk_forest
    [ mk_node
        (mk_account_update_body Signature No funder Token_id.default
           (-(owner_seed + creation_fee)) )
        []
    ; mk_node
        (mk_account_update_body Signature No owner Token_id.default owner_seed)
        []
    ]
  |> mk_zkapp_command ~fee ~fee_payer_pk ~fee_payer_nonce

(* the owner mints [initial_mint] of its token to each (new) holder, paying their
   account-creation fees out of the seed funded above *)
let build_mint_all_command ~constraint_constants ~fee ~fee_payer_pk
    ~fee_payer_nonce ~(ct : custom_token) =
  let open Zkapp_command_builder in
  let creation_fee = account_creation_fee constraint_constants in
  let k = Array.length ct.holders in
  let children =
    Array.to_list ct.holders
    |> List.map ~f:(fun h ->
           mk_node
             (mk_account_update_body Signature Parents_own_token h ct.token_id
                ct.initial_mint )
             [] )
  in
  mk_forest
    [ mk_node
        (mk_account_update_body Signature No ct.owner Token_id.default
           (-(k * creation_fee)) )
        children
    ]
  |> mk_zkapp_command ~fee ~fee_payer_pk ~fee_payer_nonce

(* one load command: usually a balanced transfer between two holders,
   periodically a re-mint to the holder with the smallest balance *)
let build_load_command ~fee ~fee_payer_pk ~fee_payer_nonce ~memo ~counter
    ~(ct : custom_token) =
  let open Zkapp_command_builder in
  let k = Array.length ct.holders in
  let extremum cmp =
    let idx = ref 0 in
    Array.iteri ct.balances ~f:(fun i b ->
        if cmp b ct.balances.(!idx) then idx := i ) ;
    !idx
  in
  let owner_node children =
    mk_node
      (mk_account_update_body Signature No ct.owner Token_id.default 0)
      children
  in
  let holder_node i amt =
    mk_node
      (mk_account_update_body Signature Parents_own_token ct.holders.(i)
         ct.token_id amt )
      []
  in
  let forest =
    if counter mod ct.mint_period = 0 then (
      let i = extremum ( < ) in
      ct.balances.(i) <- ct.balances.(i) + ct.initial_mint ;
      mk_forest [ owner_node [ holder_node i ct.initial_mint ] ] )
    else
      let sender = extremum ( > ) in
      let receiver =
        let r = (sender + 1 + (counter mod (k - 1))) mod k in
        if r = sender then (sender + 1) mod k else r
      in
      let max_amt = Int.min ct.balances.(sender) ct.transfer_cap in
      let amt = if max_amt <= 1 then 1 else 1 + Random.int max_amt in
      ct.balances.(sender) <- ct.balances.(sender) - amt ;
      ct.balances.(receiver) <- ct.balances.(receiver) + amt ;
      mk_forest
        [ owner_node [ holder_node sender (-amt); holder_node receiver amt ] ]
  in
  forest |> mk_zkapp_command ~memo ~fee ~fee_payer_pk ~fee_payer_nonce

(* create the owner, mint to all holders, and wait for both to appear in the
   best-tip ledger. Returns [true] once the token and its holders exist. *)
let setup_custom_token
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) ~mina
    ~logger ~(fee_payer_array : Signature_lib.Keypair.t Array.t) ~keymap
    ~(zkapp_command_details : Types.Input.Itn.ZkappCommandsDetails.input)
    ~stop_signal ~stop_time ~uuid ~(ct : custom_token) =
  O1trace.thread "itn_setup_custom_token"
  @@ fun () ->
  let num_fee_payers = Array.length fee_payer_array in
  let k = Array.length ct.holders in
  let creation_fee = account_creation_fee constraint_constants in
  let owner_seed = (k + 2) * creation_fee in
  let expired () =
    Time.( >= ) (Time.now ()) stop_time || Ivar.is_full stop_signal
  in
  let get_ledger () =
    Option.map (Utils.get_ledger_and_breadcrumb mina) ~f:fst
  in
  let account_exists ledger acct_id =
    Option.is_some (Mina_ledger.Ledger.location_of_account ledger acct_id)
  in
  let wait_until predicate =
    Deferred.repeat_until_finished ()
    @@ fun () ->
    if expired () then Deferred.return (`Finished false)
    else
      match get_ledger () with
      | Some ledger when predicate ledger ->
          Deferred.return (`Finished true)
      | _ ->
          let%map () =
            Async.after
              (Time.Span.of_ms
                 ( Float.of_int constraint_constants.block_window_duration_ms
                 /. 3.0 ) )
          in
          `Repeat ()
  in
  let send_cmd ~(fee_payer : Signature_lib.Keypair.t) ~build =
    match get_ledger () with
    | None ->
        Deferred.return (Error "no best tip ledger available")
    | Some ledger ->
        let fee_payer_nonce = (Utils.account_of_kp fee_payer ledger).nonce in
        let fee_payer_pk =
          Signature_lib.Public_key.compress fee_payer.public_key
        in
        let cmd = build ~fee_payer_pk ~fee_payer_nonce in
        let%bind authed =
          Zkapp_command_builder.replace_authorizations ~keymap cmd
        in
        Zkapps.send_zkapp_command mina
          (Zkapp_command.read_all_proofs_from_disk authed)
  in
  let fee_payer0 = fee_payer_array.(0) in
  let funder = fee_payer_array.(1 mod num_fee_payers) in
  let owner_id =
    Account_id.create
      (Signature_lib.Public_key.compress ct.owner.public_key)
      Token_id.default
  in
  [%log info] "Initializing custom token for handle %s" (Uuid.to_string uuid) ;
  let%bind () =
    match%map
      send_cmd ~fee_payer:fee_payer0
        ~build:(fun ~fee_payer_pk ~fee_payer_nonce ->
          build_owner_command ~constraint_constants
            ~fee:(gen_fee ~zkapp_command_details)
            ~fee_payer_pk ~fee_payer_nonce ~funder ~owner:ct.owner ~owner_seed )
    with
    | Ok _ ->
        [%log info] "Submitted custom-token owner creation"
    | Error e ->
        [%log error] "Failed to submit custom-token owner creation: $error"
          ~metadata:[ ("error", `String e) ]
  in
  match%bind wait_until (fun ledger -> account_exists ledger owner_id) with
  | false ->
      Deferred.return false
  | true ->
      let%bind () =
        match%map
          send_cmd ~fee_payer:fee_payer0
            ~build:(fun ~fee_payer_pk ~fee_payer_nonce ->
              build_mint_all_command ~constraint_constants
                ~fee:(gen_fee ~zkapp_command_details)
                ~fee_payer_pk ~fee_payer_nonce ~ct )
        with
        | Ok _ ->
            [%log info] "Submitted custom-token mint to %d holders" k
        | Error e ->
            [%log error] "Failed to submit custom-token mint: $error"
              ~metadata:[ ("error", `String e) ]
      in
      let%map all_present =
        wait_until (fun ledger ->
            Array.for_all ct.holders ~f:(fun h ->
                account_exists ledger
                  (Account_id.create
                     (Signature_lib.Public_key.compress h.public_key)
                     ct.token_id ) ) )
      in
      if all_present then (
        Array.fill ct.balances ~pos:0 ~len:(Array.length ct.balances)
          ct.initial_mint ;
        [%log info] "Custom token initialized with %d holders for handle %s" k
          (Uuid.to_string uuid) ;
        true )
      else false

(* the custom-token load loop: send a transfer (or periodic re-mint) each tick *)
let send_custom_token_zkapps
    ~(fee_payer_array : Signature_lib.Keypair.t Array.t) ~tm_end ~scheduler_tbl
    ~uuid ~keymap ~stop_signal ~mina
    ~(zkapp_command_details : Types.Input.Itn.ZkappCommandsDetails.input)
    ~wait_span ~logger ~(ct : custom_token) init_tm_next init_counter =
  O1trace.thread "itn_send_custom_token_zkapps"
  @@ fun () ->
  let wait_span_ms = Time.Span.to_ms wait_span |> int_of_float in
  let repeat tm_next counter =
    let%map () = Async_unix.at tm_next in
    let open Time in
    let next_tm_next = add tm_next wait_span in
    let now = now () in
    let next_tm_next =
      if next_tm_next <= now then
        let span = diff now next_tm_next |> Span.to_ms in
        let additive =
          wait_span_ms - (int_of_float span % wait_span_ms)
          |> float_of_int |> Span.of_ms
        in
        add now additive
      else next_tm_next
    in
    `Repeat (next_tm_next, counter + 1)
  in
  let num_fee_payers = Array.length fee_payer_array in
  let fee_payer_nonces =
    match Utils.get_ledger_and_breadcrumb mina with
    | Some (ledger, _) ->
        Array.map fee_payer_array ~f:(fun kp ->
            ref (Utils.account_of_kp kp ledger).nonce )
    | None ->
        Array.map fee_payer_array ~f:(fun _ -> ref Account.Nonce.zero)
  in
  Deferred.repeat_until_finished (init_tm_next, init_counter)
  @@ fun (tm_next, counter) ->
  if Time.( >= ) (Time.now ()) tm_end then (
    [%log info] "Scheduled zkApp commands with handle %s has expired"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.return (`Finished ()) )
  else if Ivar.is_full stop_signal then (
    [%log info] "Stopping scheduled zkApp commands with handle %s"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.return (`Finished ()) )
  else
    let ndx = counter mod num_fee_payers in
    let fee_payer = fee_payer_array.(ndx) in
    let fee_payer_pk = Signature_lib.Public_key.compress fee_payer.public_key in
    let fee_payer_nonce = !(fee_payer_nonces.(ndx)) in
    let fee = gen_fee ~zkapp_command_details in
    let memo =
      String.prefix
        (sprintf "%s-%d" zkapp_command_details.memo_prefix counter)
        Signed_command_memo.max_input_length
    in
    let zkapp_command =
      build_load_command ~fee ~fee_payer_pk ~fee_payer_nonce ~memo ~counter ~ct
    in
    let%bind zkapp_command =
      O1trace.thread "itn_replace_custom_token_auth"
      @@ fun () ->
      Zkapp_command_builder.replace_authorizations ~keymap zkapp_command
    in
    let%bind () =
      O1trace.thread "itn_send_custom_token_zkapp"
      @@ fun () ->
      match%map
        Zkapps.send_zkapp_command mina
          (Zkapp_command.read_all_proofs_from_disk zkapp_command)
      with
      | Ok _ ->
          fee_payer_nonces.(ndx) := Account.Nonce.succ fee_payer_nonce ;
          [%log info]
            "Sent out custom-token zkApp with fee payer's summary $summary"
            ~metadata:
              [ ( "summary"
                , User_command.fee_payer_summary_json
                    (Zkapp_command zkapp_command) )
              ]
      | Error e ->
          [%log info]
            "Failed to send out custom-token zkApp command, see $error"
            ~metadata:[ ("error", `String e) ]
    in
    repeat tm_next counter

(* stand up the custom token, then run the transfer/re-mint load against it.
   The default-token counterpart is [send_zkapps]; keeping the setup+load
   sequencing here (rather than inline in the GraphQL resolver) keeps the two
   entry points symmetric. *)
let run_custom_token_load
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) ~mina
    ~logger ~(fee_payer_array : Signature_lib.Keypair.t Array.t) ~scheduler_tbl
    ~keymap
    ~(zkapp_command_details : Types.Input.Itn.ZkappCommandsDetails.input)
    ~stop_signal ~tm_end ~wait_span ~uuid ~(ct : custom_token) =
  let%bind setup_ok =
    setup_custom_token ~constraint_constants ~mina ~logger ~fee_payer_array
      ~keymap ~zkapp_command_details ~stop_signal ~stop_time:tm_end ~uuid ~ct
  in
  if setup_ok then
    let tm_next = Time.add (Time.now ()) wait_span in
    send_custom_token_zkapps ~fee_payer_array ~tm_end ~scheduler_tbl ~uuid
      ~keymap ~stop_signal ~mina ~zkapp_command_details ~wait_span ~logger ~ct
      tm_next 0
  else (
    [%log error] "Custom token setup did not complete, stopping handle %s"
      (Uuid.to_string uuid) ;
    Uuid.Table.remove scheduler_tbl uuid ;
    Deferred.unit )
