(** An agent that pokes at Coda and peeks at Rosetta to see if things look alright *)

open Core_kernel
open Lib
open Async
open Models

let wait span = Async.after span |> Deferred.map ~f:Result.return

(* Keep trying to run `step` `retry_count` many times initially waiting for `initial_delay` and each time waiting `each_delay` *)
let keep_trying ~step ~retry_count ~initial_delay ~each_delay ~failure_reason =
  let open Deferred.Result.Let_syntax in
  let rec go = function
    | 0 ->
        Deferred.Result.fail
          (Errors.create ~context:failure_reason `Invariant_violation)
    | i -> (
        match%bind step () with
        | `Succeeded ->
            return ()
        | `Failed ->
            let%bind () = wait each_delay in
            go (i - 1) )
  in
  let%bind () = wait initial_delay in
  go retry_count

(* TODO: Break up this function in the next PR *)
let check_new_account_payment ~logger ~rosetta_uri ~graphql_uri =
  let open Core.Time in
  let open Deferred.Result.Let_syntax in
  let module Error = struct
    include Error

    let equal e1 e2 =
      Yojson.Safe.equal (Error.to_yojson e1) (Error.to_yojson e2)
  end in
  (* Stop staking so we can rely on things being in the mempool *)
  let%bind _res = Poke.Staking.disable ~graphql_uri in
  (* Figure out our network identifier *)
  let%bind network_response = Peek.Network.list ~rosetta_uri ~logger in
  (* Wait until we are "synced" -- on debug nets this is when block production begins *)
  [%log debug] "pre status" ;
  let%bind () =
    keep_trying
      ~step:(fun () ->
        let status_r_dr =
          Peek.Network.status ~rosetta_uri ~network_response ~logger
        in
        let%map status_r = status_r_dr in
        if
          [%eq: (string option, Error.t) result]
            (Result.map status_r ~f:(fun status ->
                 Option.bind status.Network_status_response.sync_status
                   ~f:(fun sync_status -> sync_status.stage) ))
            (Ok (Some "Synced"))
        then `Succeeded
        else `Failed )
      ~retry_count:45 ~initial_delay:(Span.of_sec 2.0)
      ~each_delay:(Span.of_sec 2.0) ~failure_reason:"Took too long to sync"
  in
  [%log debug] "post status" ;
  (* Unlock the account *)
  let%bind _ = Poke.Account.unlock ~graphql_uri in
  [%log debug] "unlocked account" ;
  (* Send a payment *)
  let%bind hash =
    Poke.SendTransaction.payment ~fee:(`Int 2_000_000_000)
      ~amount:(`Int 5_000_000_000)
      ~to_:
        (`String
          "ZsMSUtsVDsfGXFf2jMerfdLemdhu4NRrmA8T948sB5WfKNrrHuwLPj4Pjk34CrfJTVy")
      ~graphql_uri ()
  in
  [%log debug] "made payment" ;
  let%bind () = wait (Span.of_sec 2.0) in
  (* Grab the mempool and find the payment inside *)
  [%log debug] "hitting mempool" ;
  let%bind () =
    keep_trying
      ~step:(fun () ->
        let%map mempool_r =
          Peek.Mempool.mempool ~rosetta_uri ~network_response ~logger
        in
        match
          Result.map mempool_r ~f:(fun mempool ->
              List.find mempool.Mempool_response.transaction_identifiers
                ~f:(fun ident ->
                  String.equal ident.Transaction_identifier.hash hash ) )
        with
        | Error _ ->
            `Failed
        | Ok None ->
            `Failed
        | Ok (Some _) ->
            `Succeeded )
      ~retry_count:5 ~initial_delay:(Span.of_ms 100.0)
      ~each_delay:(Span.of_sec 1.0)
      ~failure_reason:"Took too long to appear in mempool"
  in
  (* Pull specific account out of mempool *)
  let%bind mempool_res =
    Peek.Mempool.transaction ~rosetta_uri ~network_response ~logger ~hash
  in
  let expected =
    Operation_expectation.
      [ { amount= Some (-2_000_000_000)
        ; account=
            Some
              { Account.pk=
                  "ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8"
              ; token_id= Unsigned.UInt64.of_int 1 }
        ; status= "Pending"
        ; _type= "fee_payer_dec" }
      ; { amount= Some (-5_000_000_000)
        ; account=
            Some
              { Account.pk=
                  "ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8"
              ; token_id= Unsigned.UInt64.of_int 1 }
        ; status= "Pending"
        ; _type= "payment_source_dec" }
      ; { amount= Some 5_000_000_000
        ; account=
            Some
              { Account.pk=
                  "ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8"
              ; token_id= Unsigned.UInt64.of_int 1 }
        ; status= "Pending"
        ; _type= "payment_receiver_inc" } ]
  in
  let%bind () =
    List.fold (List.zip_exn expected mempool_res.transaction.operations)
      ~init:(Result.return ()) ~f:(fun acc (t, op) ->
        let open Result.Let_syntax in
        let%bind () = acc in
        Operation_expectation.similar t op
        |> Result.map_error ~f:(fun e -> (e, op)) )
    |> Result.map_error ~f:(fun (e, op) ->
           Errors.create
             ~context:
               (sprintf
                  !"Unexpected operations in mempool reason: %{sexp: \
                    Operation_expectation.Reason.t}, raw: %s"
                  e (Operation.show op))
             `Invariant_violation )
    |> Deferred.return
  in
  (* Succeed! (for now) *)
  return ()

let run ~logger ~rosetta_uri ~graphql_uri =
  let open Deferred.Result.Let_syntax in
  let%bind () = check_new_account_payment ~logger ~rosetta_uri ~graphql_uri in
  [%log info] "Finished running test-agent" ;
  return ()

let command =
  let open Command.Let_syntax in
  let%map_open rosetta_uri =
    flag "rosetta-uri" ~doc:"URI of Rosetta endpoint to connect to"
      Cli.required_uri
  and graphql_uri =
    flag "graphql-uri" ~doc:"URI of Coda GraphQL endpoint to connect to"
      Cli.required_uri
  and log_json =
    flag "log-json" ~doc:"Print log output as JSON (default: plain text)"
      no_arg
  and log_level =
    flag "log-level" ~doc:"Set log level (default: Info)" Cli.log_level
  in
  let open Deferred.Let_syntax in
  fun () ->
    let logger = Logger.create () in
    Cli.logger_setup log_json log_level ;
    [%log info] "Rosetta test-agent starting" ;
    match%bind run ~logger ~rosetta_uri ~graphql_uri with
    | Ok () ->
        [%log info] "Rosetta test-agent stopping successfully" ;
        return ()
    | Error e ->
        [%log error] "Rosetta test-agent stopping with a failure: %s"
          (Errors.show e) ;
        exit 1

let () =
  Command.run
    (Command.async ~summary:"Run agent to poke at Coda and peek at Rosetta"
       command)
