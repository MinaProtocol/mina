open Core
open Async_kernel
module TL = Merkle_ledger.Test_ledger

module Tests
    (L : Merkle_ledger.Test.Ledger_intf) (Num_accts : sig
        val num_accts : int
    end) =
struct
  module Adjhash = struct
    include TL.Hash

    type t = hash [@@deriving bin_io, compare, hash, sexp, compare]

    type account = TL.Account.t

    let to_hash (x: t) = x

    let equal h1 h2 = compare_hash h1 h2 = 0
  end

  module Ledger' = struct
    include L

    type key = unit

    type path = Path.t
  end

  module SL =
    Syncable_ledger.Make (L.Addr) (TL.Key) (TL.Account) (Adjhash) (Adjhash)
      (Ledger')
      (struct
        let subtree_height = 3
      end)

  module SR =
    Syncable_ledger.Make_sync_responder (L.Addr) (TL.Key) (TL.Account)
      (Adjhash)
      (Adjhash)
      (Ledger')
      (SL)

  let%test "full_sync_entirely_different" =
    let l1, _k1 = L.load_ledger Num_accts.num_accts 1 in
    let l2, _k2 = L.load_ledger Num_accts.num_accts 2 in
    L.set_syncing l1 ;
    L.set_syncing l2 ;
    L.clear_syncing l1 ;
    L.clear_syncing l2 ;
    let desired_root = L.merkle_root l2 in
    let lsync = SL.create l1 desired_root in
    let qr = SL.query_reader lsync in
    let aw = SL.answer_writer lsync in
    let seen_queries = ref [] in
    let sr = SR.create l2 (fun q -> seen_queries := q :: !seen_queries) in
    don't_wait_for
      (Linear_pipe.iter qr ~f:(fun (_hash, query) ->
           let answ = SR.answer_query sr query in
           Linear_pipe.write aw (desired_root, answ) )) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          SL.wait_until_valid lsync desired_root )
    with
    | `Ok mt -> Adjhash.equal desired_root (L.merkle_root mt)
    | `Target_changed -> false

  let%test_unit "new_goal_soon" =
    let l1, _k1 = L.load_ledger Num_accts.num_accts 1 in
    let l2, _k2 = L.load_ledger Num_accts.num_accts 2 in
    let l3, _k3 = L.load_ledger Num_accts.num_accts 3 in
    L.set_syncing l1 ;
    L.set_syncing l2 ;
    L.clear_syncing l1 ;
    L.clear_syncing l2 ;
    let desired_root = ref @@ L.merkle_root l2 in
    let lsync = SL.create l1 !desired_root in
    let qr = SL.query_reader lsync in
    let aw = SL.answer_writer lsync in
    let seen_queries = ref [] in
    let sr =
      ref @@ SR.create l2 (fun q -> seen_queries := q :: !seen_queries)
    in
    let ctr = ref 0 in
    don't_wait_for
      (Linear_pipe.iter qr ~f:(fun (_hash, query) ->
           ctr := !ctr + 1 ;
           if !ctr = Num_accts.num_accts then (
             sr := SR.create l3 (fun q -> seen_queries := q :: !seen_queries) ;
             desired_root := L.merkle_root l3 ;
             SL.new_goal lsync !desired_root ;
             Deferred.unit )
           else
             let answ = SR.answer_query !sr query in
             Linear_pipe.write aw (!desired_root, answ) )) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          SL.wait_until_valid lsync !desired_root )
    with
    | `Ok mt ->
        [%test_result : Adjhash.t] ~expect:(L.merkle_root l2)
          (L.merkle_root mt)
    | `Target_changed ->
      match
        Async.Thread_safe.block_on_async_exn (fun () ->
            SL.wait_until_valid lsync !desired_root )
      with
      | `Ok mt ->
          [%test_result : Adjhash.t] ~expect:(L.merkle_root l3)
            (L.merkle_root mt)
      | `Target_changed -> failwith "the target changed again"
end

module TestL3_3 =
  Tests (Merkle_ledger.Test.L3)
    (struct
      let num_accts = 3
    end)

module TestL3_8 =
  Tests (Merkle_ledger.Test.L3)
    (struct
      let num_accts = 8
    end)

module TestL16_3 =
  Tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 3
    end)

module TestL16_20 =
  Tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 20
    end)

module TestL16_1024 =
  Tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 1024
    end)

module TestL16_1025 =
  Tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 80
    end)

module TestL16_65536 =
  Tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 65536
    end)
