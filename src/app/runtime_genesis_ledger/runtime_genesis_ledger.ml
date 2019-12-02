open Core
open Async
open Coda_base
open Signature_lib

module Account_data = struct
  type account_data =
    { pk: Public_key.Compressed.t
    ; sk: Private_key.t option
    ; balance: Currency.Balance.t
    ; delegate: Public_key.Compressed.t option }
  [@@deriving yojson]

  type t = account_data list [@@deriving yojson]
end

type t = Ledger.t

let sample_account_data1 : Account_data.account_data =
  let keys = Signature_lib.Keypair.create () in
  let balance = Currency.Balance.of_int 1000 in
  let delegate = None in
  { pk= Public_key.compress keys.public_key
  ; sk= Some keys.private_key
  ; balance
  ; delegate }

let sample_account_data2 : Account_data.account_data =
  let keys = Signature_lib.Keypair.create () in
  let balance = Currency.Balance.of_int 1000 in
  let pk = Public_key.compress keys.public_key in
  let delegate = Some pk in
  {pk; sk= Some keys.private_key; balance; delegate}

let sample_account_data3 : Account_data.account_data =
  let keys = Signature_lib.Keypair.create () in
  let balance = Currency.Balance.of_int 1000 in
  let delegate = None in
  {pk= Public_key.compress keys.public_key; sk= None; balance; delegate}

let sample_list =
  [sample_account_data1; sample_account_data2; sample_account_data3]

let generate_base_proof ~ledger =
  let%map (module Keys) = Keys_lib.Keys.create () in
  let genesis_ledger = lazy ledger in
  let genesis_state =
    Lazy.force (Coda_state.Genesis_protocol_state.t ~genesis_ledger)
  in
  let base_hash = Keys.Step.instance_hash genesis_state.data in
  let wrap hash proof =
    let open Snark_params in
    let module Wrap = Keys.Wrap in
    let input = Wrap_input.of_tick_field hash in
    let proof =
      Tock.prove
        (Tock.Keypair.pk Wrap.keys)
        Wrap.input {Wrap.Prover_state.proof} Wrap.main input
    in
    assert (Tock.verify proof (Tock.Keypair.vk Wrap.keys) Wrap.input input) ;
    proof
  in
  let base_proof =
    let open Snark_params in
    let prover_state =
      { Keys.Step.Prover_state.prev_proof= Tock.Proof.dummy
      ; wrap_vk= Tock.Keypair.vk Keys.Wrap.keys
      ; prev_state=
          Lazy.force (Coda_state.Protocol_state.negative_one ~genesis_ledger)
      ; genesis_state_hash= genesis_state.hash
      ; expected_next_state= None
      ; update=
          Lazy.force (Coda_state.Snark_transition.genesis ~genesis_ledger) }
    in
    let main x =
      Tick.handle (Keys.Step.main x)
        (Lazy.force
           (Consensus.Data.Prover_state.precomputed_handler ~genesis_ledger))
    in
    let tick =
      Tick.prove
        (Tick.Keypair.pk Keys.Step.keys)
        (Keys.Step.input ()) prover_state main base_hash
    in
    assert (
      Tick.verify tick
        (Tick.Keypair.vk Keys.Step.keys)
        (Keys.Step.input ()) base_hash ) ;
    wrap base_hash tick
  in
  (base_hash, base_proof)

let create : directory_name:string -> Account_data.t -> t =
 fun ~directory_name account_list ->
  let ledger = Ledger.create ~directory_name () in
  let _accounts =
    List.fold ~init:[] account_list ~f:(fun acc {pk; sk; balance; delegate} ->
        let account =
          let base_acct = Account.create pk balance in
          {base_acct with delegate= Option.value ~default:pk delegate}
        in
        Ledger.create_new_account_exn ledger account.public_key account ;
        (sk, account) :: acc )
  in
  ledger

let commit ledger = Ledger.commit ledger

let main accounts_json_file ledger_dir =
  let open Deferred.Let_syntax in
  let%bind ledger_dir_contents = Sys.ls_dir ledger_dir in
  let%bind accounts =
    match%map
      Deferred.Or_error.try_with_join (fun () ->
          let%map accounts_str = Reader.file_contents accounts_json_file in
          let res = Yojson.Safe.from_string accounts_str in
          match Account_data.of_yojson res with
          | Ok res ->
              Ok res
          | Error s ->
              Error
                (Error.of_string
                   (sprintf "Account_data.of_yojson failed: %s" s)) )
    with
    | Ok res ->
        Ok res
    | Error e ->
        Or_error.errorf "Could not read accounts from file:%s\n%s"
          accounts_json_file (Error.to_string_hum e)
  in
  match
    Or_error.try_with_join (fun () ->
        let open Or_error.Let_syntax in
        let%bind () =
          if List.is_empty ledger_dir_contents then Ok ()
          else Error (Error.of_string "Ledger directory not empty")
        in
        let vrf_account : Account_data.account_data =
          let pk, _ = Coda_state.Consensus_state_hooks.genesis_winner in
          {pk; sk= None; balance= Currency.Balance.of_int 1000; delegate= None}
        in
        let%map accounts = accounts in
        let ledger =
          create ~directory_name:ledger_dir (vrf_account :: accounts)
        in
        let () = commit ledger in
        ledger )
  with
  | Ok ledger ->
      let%bind _base_hash, base_proof = generate_base_proof ~ledger in
      let%map wr = Writer.open_file (ledger_dir ^/ "base_proof") in
      Writer.write wr (Proof.Stable.V1.sexp_of_t base_proof |> Sexp.to_string)
  | Error e ->
      failwithf "Failed to create genesis ledger\n%s" (Error.to_string_hum e)
        ()

let () =
  Command.run
    (Command.async
       ~summary:
         "Create the genesis ledger with configurable accounts, balances, and \
          delegates "
       Command.(
         let open Let_syntax in
         let%map accounts_json =
           let open Command.Param in
           flag "accounts-file"
             ~doc:
               "Filepath of the json file that has account data of the format \
                [{\"pk\":public-key-string, \
                \"sk\":optional-secret-key-string, \"balance\":int, \
                \"delegate\":optional-public-key-string}]"
             (required string)
         and ledger_dir =
           let open Command.Param in
           flag "ledger-dir" ~doc:"Dir where the genesis ledger will be saved"
             (required string)
         in
         fun () -> main accounts_json ledger_dir))

let _load : directory_name:string -> t Lazy.t =
 fun ~directory_name -> lazy (Ledger.create ~directory_name ())
