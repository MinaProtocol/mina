(* genesis_ledger_from_tsv.ml -- create JSON-format genesis ledger from tab-separated-value data *)

open Core_kernel
open Async
open Mina_numbers
open Signature_lib

let accounts_tbl : unit String.Table.t = String.Table.create ()

let add_account pk =
  match String.Table.add accounts_tbl ~key:pk ~data:() with
  | `Ok ->
      ()
  | `Duplicate ->
      failwithf "Duplicate entry for public key %s" pk ()

let delegates_tbl : unit String.Table.t = String.Table.create ()

let add_delegate pk = ignore (String.Table.add delegates_tbl ~key:pk ~data:())

let validate_pk pk =
  try ignore (Public_key.Compressed.of_base58_check_exn pk)
  with _ -> failwithf "Invalid Base58Check for public key: %s" pk ()

let slot_duration_ms =
  Consensus.Configuration.t
    ~constraint_constants:Genesis_constants.Constraint_constants.compiled
    ~protocol_constants:Genesis_constants.compiled.protocol
  |> Consensus.Configuration.slot_duration

(* a month = 30 days, for purposes of vesting *)
let slots_per_month = 30 * 24 * 60 * 60 * 1000 / slot_duration_ms

let valid_mina_amount amount =
  let is_num_string s = String.for_all s ~f:Char.is_digit in
  match String.split ~on:'.' amount with
  | [whole] ->
      is_num_string whole
  | [whole; decimal] when String.length decimal <= 9 ->
      is_num_string whole && is_num_string decimal
  | _ ->
      false

(* for delegatee that does not have an entry in the TSV,
   generate an entry with zero balance, untimed
*)
let generate_delegate_account ~logger delegatee_pk =
  [%log info] "Generating account for delegatee $delegatee"
    ~metadata:[("delegatee", `String delegatee_pk)] ;
  let pk = Some delegatee_pk in
  let balance = Currency.Balance.zero in
  let timing = None in
  let delegate = None in
  { Runtime_config.Json_layout.Accounts.Single.default with
    pk
  ; balance
  ; timing
  ; delegate }

let generate_missing_delegate_accounts ~logger =
  (* for each delegate that doesn't have a corresponding account,
     generate an account
  *)
  let delegates = String.Table.keys delegates_tbl in
  let missing_delegates =
    List.filter delegates ~f:(fun delegate ->
        not (String.Table.mem accounts_tbl delegate) )
  in
  let delegate_accounts =
    List.map missing_delegates ~f:(generate_delegate_account ~logger)
  in
  (delegate_accounts, List.length delegate_accounts)

let runtime_config_account ~logger ~wallet_pk ~amount ~initial_min_balance
    ~cliff_time_months ~cliff_amount ~unlock_frequency ~unlock_amount
    ~delegatee_pk =
  [%log info] "Processing record for $wallet_pk"
    ~metadata:[("wallet_pk", `String wallet_pk)] ;
  (* validate wallet public key *)
  validate_pk wallet_pk ;
  let pk = Some wallet_pk in
  add_account wallet_pk ;
  let balance =
    if valid_mina_amount amount then
      Currency.Balance.of_formatted_string amount
    else failwithf "Amount is not a valid Mina amount: %s" amount ()
  in
  let initial_minimum_balance =
    (* if omitted in the TSV, use balance *)
    if String.is_empty initial_min_balance then balance
    else if valid_mina_amount initial_min_balance then
      Currency.Balance.of_formatted_string initial_min_balance
    else
      failwithf "Initial minimum balance is not a valid Mina amount: %s"
        initial_min_balance ()
  in
  let cliff_time =
    Global_slot.of_int (Int.of_string cliff_time_months * slots_per_month)
  in
  let cliff_amount =
    if valid_mina_amount cliff_amount then
      Currency.Amount.of_formatted_string cliff_amount
    else
      failwithf "Cliff amount is not a valid Mina amount: %s" cliff_amount ()
  in
  let vesting_period =
    match Int.of_string unlock_frequency with
    | 0 ->
        Global_slot.of_int 1
    | 1 ->
        Global_slot.of_int slots_per_month
    | _ ->
        failwithf "Expected unlock frequency to be 0 or 1, got %s"
          unlock_frequency ()
  in
  let vesting_increment =
    if valid_mina_amount unlock_amount then
      Currency.Amount.of_formatted_string unlock_amount
    else
      failwithf "Unlock amount is not a valid Mina amount: %s" unlock_amount ()
  in
  let timing =
    Some
      { Runtime_config.Json_layout.Accounts.Single.Timed.initial_minimum_balance
      ; cliff_time
      ; cliff_amount
      ; vesting_period
      ; vesting_increment }
  in
  let delegate =
    (* 0 denotes "no delegation" *)
    if String.equal delegatee_pk "0" then None
    else (
      (* validate delegatee *)
      validate_pk delegatee_pk ;
      add_delegate delegatee_pk ;
      Some delegatee_pk )
  in
  { Runtime_config.Json_layout.Accounts.Single.default with
    pk
  ; balance
  ; timing
  ; delegate }

let account_of_tsv ~logger tsv =
  match String.split tsv ~on:'\t' with
  | [ wallet_pk
    ; amount
    ; initial_min_balance
    ; cliff_time_months
    ; cliff_amount
    ; unlock_frequency
    ; unlock_amount
    ; delegatee_pk ] ->
      runtime_config_account ~logger ~wallet_pk ~amount ~initial_min_balance
        ~cliff_time_months ~cliff_amount ~unlock_frequency ~unlock_amount
        ~delegatee_pk
  | _ ->
      failwithf "TSV line does not contain expected fields: %s" tsv ()

let remove_commas s = String.filter s ~f:(fun c -> not (Char.equal c ','))

let main ~tsv_file ~output_file () =
  let logger = Logger.create () in
  let provided_accounts, num_accounts =
    In_channel.with_file tsv_file ~f:(fun in_channel ->
        [%log info] "Opened TSV file $tsv_file"
          ~metadata:[("tsv_file", `String tsv_file)] ;
        let rec go accounts num_accounts =
          match In_channel.input_line in_channel with
          | Some line ->
              let underscored_line = remove_commas line in
              let account =
                try account_of_tsv ~logger underscored_line
                with exn ->
                  [%log fatal]
                    "Could not process record at row $row_number, error: $error"
                    ~metadata:
                      [ ("row_number", `Int (num_accounts + 2))
                      ; ("error", `String (Exn.to_string exn))
                      ; ("tsv", `String line) ] ;
                  Core_kernel.exit 1
              in
              go (account :: accounts) (num_accounts + 1)
          | None ->
              (List.rev accounts, num_accounts)
        in
        (* skip first line *)
        let _headers = In_channel.input_line in_channel in
        go [] 0 )
  in
  [%log info] "Processed %d records" num_accounts ;
  let generated_accounts, num_generated =
    generate_missing_delegate_accounts ~logger
  in
  [%log info] "Generated %d delegate accounts" num_generated ;
  [%log info] "Writing JSON output" ;
  let accounts = provided_accounts @ generated_accounts in
  Out_channel.with_file output_file ~f:(fun out_channel ->
      let json =
        `List (List.map accounts ~f:Runtime_config.Accounts.Single.to_yojson)
      in
      Out_channel.output_string out_channel (Yojson.Safe.to_string json) ;
      Out_channel.newline out_channel ) ;
  return ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async ~summary:"Write blocks to an archive database"
        (let%map output_file =
           Param.flag "output-file"
             ~doc:
               "PATH File that will contain the genesis ledger in JSON format"
             Param.(required string)
         and tsv_file =
           Param.flag "tsv-file"
             ~doc:
               "PATH File containing genesis ledger in tab-separated-value \
                format"
             Param.(required string)
         in
         main ~tsv_file ~output_file)))
