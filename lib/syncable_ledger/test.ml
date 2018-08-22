open Core
open Async_kernel
module TL = Merkle_ledger.Test_ledger

module type Ledger_intf = sig
  include Syncable_ledger.Merkle_tree_intf

  val load_ledger : int -> int -> t * string list
end

module type Root_hash_intf = sig
  type t [@@deriving bin_io, compare, hash, sexp, compare]

  val equal : t -> t -> bool
end

module Tests
    (Root_hash : Root_hash_intf)
    (L : Ledger_intf with type root_hash := Root_hash.t)
    (SL : Syncable_ledger.S
          with type merkle_tree := L.t
           and type hash := L.hash
           and type root_hash := Root_hash.t
           and type addr := L.addr
           and type merkle_path := L.path
           and type account := L.account)
    (SR : Syncable_ledger.Responder_intf
          with type merkle_tree := L.t
           and type query := SL.query
           and type answer := SL.answer) (Num_accts : sig
        val num_accts : int
    end) =
struct
  (* not really kosher but the tests are run in-order, so this will get filled
   * in before we need it. *)
  let total_queries = ref None

  let%test "full_sync_entirely_different" =
    let l1, _k1 = L.load_ledger Num_accts.num_accts 1 in
    let l2, _k2 = L.load_ledger Num_accts.num_accts 2 in
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
    | `Ok mt ->
        total_queries := Some (List.length !seen_queries) ;
        Root_hash.equal desired_root (L.merkle_root mt)
    | `Target_changed -> false

  let%test_unit "new_goal_soon" =
    let l1, _k1 = L.load_ledger Num_accts.num_accts 1 in
    let l2, _k2 = L.load_ledger Num_accts.num_accts 2 in
    let l3, _k3 = L.load_ledger Num_accts.num_accts 3 in
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
      (Linear_pipe.iter qr ~f:(fun (hash, query) ->
           if not (Root_hash.equal hash !desired_root) then Deferred.unit
           else
             let res =
               if !ctr = (!total_queries |> Option.value_exn) / 2 then (
                 sr :=
                   SR.create l3 (fun q -> seen_queries := q :: !seen_queries) ;
                 desired_root := L.merkle_root l3 ;
                 SL.new_goal lsync !desired_root ;
                 Deferred.unit )
               else
                 let answ = SR.answer_query !sr query in
                 Linear_pipe.write aw (!desired_root, answ)
             in
             ctr := !ctr + 1 ;
             res )) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          SL.wait_until_valid lsync !desired_root )
    with
    | `Ok _ -> failwith "shouldn't happen"
    | `Target_changed ->
      match
        Async.Thread_safe.block_on_async_exn (fun () ->
            SL.wait_until_valid lsync !desired_root )
      with
      | `Ok mt ->
          [%test_result : Root_hash.t] ~expect:(L.merkle_root l3)
            (L.merkle_root mt)
      | `Target_changed -> failwith "the target changed again"
end

module Ledger_tests (L : sig
  include Merkle_ledger.Test.Ledger_intf (* type path = Path.t *)
end) (Num_accts : sig
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

  module L' = struct
    include L

    type path = Path.t
  end

  module SL =
    Syncable_ledger.Make (L.Addr) (TL.Account) (Adjhash) (Adjhash) (L')
      (struct
        let subtree_height = 3
      end)

  module SR =
    Syncable_ledger.Make_sync_responder (L.Addr) (TL.Account) (Adjhash)
      (Adjhash)
      (L')
      (SL)
  module Test = Tests (Adjhash) (L') (SL) (SR) (Num_accts)
end

module TestL3_3 =
  Ledger_tests (Merkle_ledger.Test.L3)
    (struct
      let num_accts = 3
    end)

module TestL3_8 =
  Ledger_tests (Merkle_ledger.Test.L3)
    (struct
      let num_accts = 8
    end)

module TestL16_3 =
  Ledger_tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 3
    end)

module TestL16_20 =
  Ledger_tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 20
    end)

module TestL16_1024 =
  Ledger_tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 1024
    end)

module TestL16_1025 =
  Ledger_tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 80
    end)

module TestL16_65536 =
  Ledger_tests (Merkle_ledger.Test.L16)
    (struct
      let num_accts = 65536
    end)
