(* Rosetta's liquid and total balance of a vesting account. At slot [s] the
   account has [minbal s] locked: liquid = total - minbal s, locked =
   minbal s (locked is reported as total - liquid). Needs a PostgreSQL
   server: MINA_TEST_POSTGRES (any database path is ignored). *)

open Core
open Async
module B = Synthetic_archive

let token = Mina_base.Token_id.(to_string default)

(* 1000 locked; at slot 10 the cliff unlocks 100, then 50 every 5 slots:
   minbal 5 = 1000, minbal 20 = 800, minbal 100 = 0 *)
let schedule =
  { B.initial_minimum_balance = 1_000
  ; cliff_time = 10
  ; cliff_amount = 100
  ; vesting_period = 5
  ; vesting_increment = 50
  }

let total = 2_000

(* liquid, total *)
type balance = int64 * int64 [@@deriving sexp, equal]

(* The account's (liquid, total) at the block at [height], from Rosetta's
   balance query. *)
let balance_of (db : B.Db.t) (account : B.account) ~height =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      let%map result =
        Lib.Account.Sql.run
          (module Conn)
          ~block_query:(Some (`This (`Height (Int64.of_int height))))
          ~address:(B.public_key account) ~token_id:token
      in
      Result.map_error result ~f:(fun e ->
          Error.of_string (Rosetta_lib.Errors.show e) )
      |> Result.map ~f:(fun (_, (b : Lib.Account.Balance_info.t), _) ->
             (b.liquid_balance, b.total_balance) ) )

(* Blocks at slots 0 and 2, where the account's last row is, then the
   requested block at [slot]. *)
let balance_at ~server_uri ~name ?timing ~slot () =
  let s = B.create () in
  let b1 =
    B.block s ~name:"b1" ~height:1 ~global_slot_since_genesis:0 Canonical
  in
  let b2 =
    B.block ~parent:b1 s ~name:"b2" ~height:2 ~global_slot_since_genesis:2
      Canonical
  in
  let (_ : B.block) =
    B.block ~parent:b2 s ~name:"b3" ~height:3 ~global_slot_since_genesis:slot
      Canonical
  in
  let alice = B.account s "alice" in
  B.account_state ?timing s b2 alice ~balance:total ;
  B.Db.with_fresh ~server_uri ~name (fun db ->
      let%bind.Deferred.Or_error (_ : B.built) = B.materialize s db in
      balance_of db alice ~height:3 )

let check ~liquid got =
  Alcotest.(check string)
    "liquid, total"
    (Sexp.to_string (sexp_of_balance (Int64.of_int liquid, Int64.of_int total)))
    (Sexp.to_string (sexp_of_balance got))

let case name ~slot ?(timing = Some schedule) ~liquid server_uri () =
  let%map.Deferred.Or_error got =
    balance_at ~server_uri ~name ?timing ~slot ()
  in
  check ~liquid got

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "rosetta_vesting_balance"
    [ ( "liquid balance"
      , [ Alcotest.test_case "vesting between the last row and the request"
            `Quick
            (run
               (case "test_rosetta_vesting_mid" ~slot:20 ~liquid:(total - 800)) )
        ; Alcotest.test_case "before the cliff" `Quick
            (run
               (case "test_rosetta_vesting_cliff" ~slot:5 ~liquid:(total - 1_000)) )
        ; Alcotest.test_case "fully vested" `Quick
            (run (case "test_rosetta_vesting_done" ~slot:100 ~liquid:total))
        ; Alcotest.test_case "untimed" `Quick
            (run
               (case "test_rosetta_vesting_untimed" ~slot:20 ~timing:None
                  ~liquid:total ) )
        ] )
    ]
