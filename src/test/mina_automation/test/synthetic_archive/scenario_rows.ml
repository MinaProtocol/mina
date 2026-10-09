(* The rows a scenario becomes, read back through the archive's loaders. *)

open Core
open Async
module B = Synthetic_archive
module Read = Read_back

type scenario =
  { s : B.t
  ; alice : B.account
  ; bob : B.account
  ; b1 : B.block
  ; b2 : B.block
  ; o2 : B.block
  ; p3 : B.block
  ; pay : B.user_command
  ; failed : B.user_command
  ; deleg : B.user_command
  ; zk_dup : B.zkapp_command
  ; zk_failed : B.zkapp_command
  ; cb2 : B.coinbase
  }

let scenario () =
  let s = B.create () in
  let alice = B.account s "alice" and bob = B.account s "bob" in
  let b1 = B.block s ~name:"b1" ~height:1 Canonical in
  let b2 = B.block s ~name:"b2" ~height:2 ~parent:b1 Canonical in
  let o2 = B.block s ~name:"o2" ~height:2 ~parent:b1 Orphaned in
  let p3 =
    B.block s ~name:"p3" ~height:3 ~parent:b2 ~protocol_version:(5, 0, 0)
      Pending
  in
  let pay =
    B.payment s ~name:"pay" ~source:alice ~receiver:bob
      ~in_:[ (b2, Applied); (o2, Applied) ]
  in
  let failed =
    B.payment s ~name:"failed" ~source:bob ~receiver:alice
      ~in_:[ (b2, Failed "Amount_insufficient_to_create_account") ]
  in
  let deleg =
    B.delegation s ~name:"deleg" ~delegator:alice ~delegate:bob
      ~in_:[ (p3, Applied) ]
  in
  let shared = B.account_update ~balance_change:5 bob in
  let zk_dup =
    B.zkapp_command s ~name:"zk_dup" ~fee_payer:alice
      ~account_updates:[ shared; shared ]
      ~in_:[ (b2, Applied) ]
  in
  let zk_failed =
    B.zkapp_command s ~name:"zk_failed" ~fee_payer:alice
      ~account_updates:
        [ B.account_update ~implicit_account_creation_fee:true alice ]
      ~in_:[ (p3, Failed "Cancelled") ]
  in
  let cb2 = B.coinbase s ~name:"cb2" ~receiver:bob b2 in
  B.account_created s b2 bob ;
  { s; alice; bob; b1; b2; o2; p3; pay; failed; deleg; zk_dup; zk_failed; cb2 }

let check_block conn built ?parent b ~status ~transaction =
  let name = B.state_hash b in
  let%bind row = Read.block conn (B.block_id built b) in
  let%map version = Read.protocol_version conn row.protocol_version_id in
  Alcotest.(check string)
    (name ^ ": state hash") (B.state_hash b) row.state_hash ;
  Alcotest.(check string) (name ^ ": status") status row.chain_status ;
  Alcotest.(check (option int))
    (name ^ ": parent")
    (Option.map parent ~f:(B.block_id built))
    row.parent_id ;
  Alcotest.(check int)
    (name ^ ": protocol version")
    transaction version.transaction

(* ids follow versions, so that a test may rely on their order *)
let check_protocol_version_ids_ascend conn built ~older ~newer =
  let%bind older = Read.block conn (B.block_id built older) in
  let%map newer = Read.block conn (B.block_id built newer) in
  Alcotest.(check bool)
    "protocol version ids ascend with versions" true
    (older.protocol_version_id < newer.protocol_version_id)

let check_blocks conn built sc =
  let%bind () =
    check_block conn built sc.b1 ~status:"canonical" ~transaction:4
  in
  let%bind () =
    check_block conn built ~parent:sc.b1 sc.b2 ~status:"canonical"
      ~transaction:4
  in
  let%bind () =
    check_block conn built ~parent:sc.b1 sc.o2 ~status:"orphaned" ~transaction:4
  in
  let%bind () =
    check_block conn built ~parent:sc.b2 sc.p3 ~status:"pending" ~transaction:5
  in
  check_protocol_version_ids_ascend conn built ~older:sc.b2 ~newer:sc.p3

let check_user_command conn built c ~payer ~receiver ~kind ~nonce =
  let%bind row = Read.user_command conn (B.user_command_id built c) in
  let%bind payer_pk = Read.public_key conn row.fee_payer_id in
  let%map receiver_pk = Read.public_key conn row.receiver_id in
  let name = B.user_command_hash c in
  Alcotest.(check string) (name ^ ": kind") kind row.command_type ;
  Alcotest.(check string) (name ^ ": fee payer") (B.public_key payer) payer_pk ;
  Alcotest.(check string)
    (name ^ ": receiver") (B.public_key receiver) receiver_pk ;
  Alcotest.(check int64) (name ^ ": nonce") (Int64.of_int nonce) row.nonce

(* loading by sequence number fails unless the row is there *)
let check_user_inclusion conn built c b ~sequence_no ?failure () =
  let%map row =
    Read.user_command_inclusion conn ~block_id:(B.block_id built b)
      ~user_command_id:(B.user_command_id built c)
      ~sequence_no
  in
  let name = B.user_command_hash c ^ " in " ^ B.state_hash b in
  Alcotest.(check string)
    (name ^ ": status")
    (if Option.is_some failure then "failed" else "applied")
    row.status ;
  Alcotest.(check (option string))
    (name ^ ": failure") failure row.failure_reason

let check_user_commands conn built sc =
  let%bind () =
    check_user_command conn built sc.pay ~payer:sc.alice ~receiver:sc.bob
      ~kind:"payment" ~nonce:0
  in
  let%bind () =
    check_user_command conn built sc.failed ~payer:sc.bob ~receiver:sc.alice
      ~kind:"payment" ~nonce:0
  in
  let%bind () =
    check_user_command conn built sc.deleg ~payer:sc.alice ~receiver:sc.bob
      ~kind:"delegation" ~nonce:1
  in
  let%bind () =
    check_user_inclusion conn built sc.pay sc.b2 ~sequence_no:0 ()
  in
  let%bind () =
    check_user_inclusion conn built sc.failed sc.b2 ~sequence_no:1
      ~failure:"Amount_insufficient_to_create_account" ()
  in
  let%bind () =
    check_user_inclusion conn built sc.pay sc.o2 ~sequence_no:0 ()
  in
  check_user_inclusion conn built sc.deleg sc.p3 ~sequence_no:0 ()

(* after b2's two user commands and one zkApp command *)
let check_coinbase conn built sc =
  let internal_command_id = B.coinbase_id built sc.cb2 in
  let%bind (_ : Archive_lib.Processor.Block_and_internal_command.t) =
    Read.internal_command_inclusion conn ~block_id:(B.block_id built sc.b2)
      ~internal_command_id ~sequence_no:3
  in
  let%bind row = Read.internal_command conn internal_command_id in
  let%map receiver = Read.public_key conn row.receiver_id in
  Alcotest.(check string) "coinbase: type" "coinbase" row.command_type ;
  Alcotest.(check string) "coinbase: receiver" (B.public_key sc.bob) receiver

let check_accounts_created conn built sc =
  let%bind rows =
    Read.accounts_created conn ~block_id:(B.block_id built sc.b2)
  in
  let%map created =
    Deferred.List.map ~how:`Sequential rows ~f:(fun row ->
        Read.public_key_of_identifier conn row.account_identifier_id )
  in
  Alcotest.(check (list string))
    "accounts created in b2"
    [ B.public_key sc.bob ]
    created

let check_account_update conn id ~account ~balance_change ~implicit_fee =
  let%bind body = Read.account_update_body conn id in
  let%map pk = Read.public_key_of_identifier conn body.account_identifier_id in
  Alcotest.(check string) "account update: account" (B.public_key account) pk ;
  Alcotest.(check string)
    "account update: balance change" balance_change body.balance_change ;
  Alcotest.(check bool)
    "account update: implicit creation fee" implicit_fee
    body.implicit_account_creation_fee

(* the same account update listed twice keeps one row *)
let check_zk_dup conn built sc =
  let zkapp_command_id = B.zkapp_command_id built sc.zk_dup in
  let%bind inclusion =
    Read.zkapp_command_inclusion conn ~block_id:(B.block_id built sc.b2)
      ~zkapp_command_id ~sequence_no:2
  in
  Alcotest.(check string) "zk_dup: status" "applied" inclusion.status ;
  let%bind command = Read.zkapp_command conn zkapp_command_id in
  match command.zkapp_account_updates_ids with
  | [| first; second |] ->
      Alcotest.(check int) "zk_dup: one shared account update" first second ;
      check_account_update conn first ~account:sc.bob ~balance_change:"5"
        ~implicit_fee:false
  | ids ->
      Alcotest.failf "zk_dup: expected 2 account updates, got %d"
        (Array.length ids)

(* a failed inclusion records the reason as the first update's failure *)
let check_zk_failed conn built sc =
  let zkapp_command_id = B.zkapp_command_id built sc.zk_failed in
  let%bind inclusion =
    Read.zkapp_command_inclusion conn ~block_id:(B.block_id built sc.p3)
      ~zkapp_command_id ~sequence_no:1
  in
  Alcotest.(check string) "zk_failed: status" "failed" inclusion.status ;
  let%bind failure =
    match inclusion.failure_reasons_ids with
    | Some [| id |] ->
        Read.zkapp_failure conn id
    | _ ->
        Alcotest.fail "zk_failed: expected one failure id"
  in
  (* index 0 is the fee payer's bucket; the first account update is 1 *)
  Alcotest.(check int) "zk_failed: failure index" 1 failure.index ;
  Alcotest.(check (array string))
    "zk_failed: failures" [| "Cancelled" |] failure.failures ;
  let%bind command = Read.zkapp_command conn zkapp_command_id in
  check_account_update conn
    command.zkapp_account_updates_ids.(0)
    ~account:sc.alice ~balance_change:"0" ~implicit_fee:true

let test server_uri () =
  let sc = scenario () in
  B.Db.with_fresh ~server_uri ~name:"test_synthetic_archive" (fun db ->
      let%bind.Deferred.Or_error built = B.materialize sc.s db in
      B.Db.with_connection db (fun conn ->
          let%bind () = check_blocks conn built sc in
          let%bind () = check_user_commands conn built sc in
          let%bind () = check_coinbase conn built sc in
          let%bind () = check_accounts_created conn built sc in
          let%bind () = check_zk_dup conn built sc in
          let%map () = check_zk_failed conn built sc in
          Ok () ) )
