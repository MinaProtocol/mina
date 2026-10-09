(* Account states: accounts_accessed rows written by the archive's own writer,
   read back with its loaders. And schema scripts run on a built database. *)

open Core
open Async
module B = Synthetic_archive
module P = Archive_lib.Processor

let timing =
  { B.initial_minimum_balance = 600
  ; cliff_time = 10
  ; cliff_amount = 100
  ; vesting_period = 5
  ; vesting_increment = 50
  }

let test server_uri () =
  let s = B.create () in
  let alice = B.account s "alice" and bob = B.account s "bob" in
  let b1 = B.block s ~name:"b1" ~height:1 Canonical in
  B.account_state ~nonce:2 s b1 alice ~balance:400 ;
  B.account_state ~timing s b1 bob ~balance:1_000 ;
  B.Db.with_fresh ~server_uri ~name:"test_synthetic_archive_account_states"
    (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      Deferred.ok
      @@ B.Db.with_connection db (fun conn ->
             let open Deferred.Let_syntax in
             let%bind rows =
               Read_back.ok ~ctx:"accounts accessed"
                 (P.Accounts_accessed.all_from_block conn (B.block_id built b1))
             in
             let%map states =
               Deferred.List.map ~how:`Sequential rows
                 ~f:(fun (row : P.Accounts_accessed.t) ->
                   let%bind pk =
                     Read_back.public_key_of_identifier conn
                       row.account_identifier_id
                   in
                   let%map t =
                     Read_back.ok ~ctx:"timing info"
                       (P.Timing_info.load conn row.timing_id)
                   in
                   sprintf "%s balance=%s nonce=%Ld timing=%s/%Ld/%s/%Ld/%s" pk
                     row.balance row.nonce t.initial_minimum_balance
                     t.cliff_time t.cliff_amount t.vesting_period
                     t.vesting_increment )
             in
             Alcotest.(check (list string))
               "accounts_accessed, with the timing the archive writes"
               (List.sort ~compare:String.compare
                  [ sprintf "%s balance=400 nonce=2 timing=0/0/0/0/0"
                      (B.public_key alice)
                  ; sprintf "%s balance=1000 nonce=0 timing=600/10/100/5/50"
                      (B.public_key bob)
                  ] )
               (List.sort ~compare:String.compare states) ) )

(* an archive from before the upgrade: upgrade.sql then downgrade.sql *)
let test_run_script server_uri () =
  B.Db.with_fresh ~server_uri ~name:"test_synthetic_archive_run_script"
    (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () = B.Db.run_script db `Upgrade in
      B.Db.run_script db `Rollback )
