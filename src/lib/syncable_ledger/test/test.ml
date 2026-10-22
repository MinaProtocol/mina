open Core
open Async_kernel
open Pipe_lib
open Network_peer

module type Ledger_intf = sig
  include Merkle_ledger.Intf.SYNC_RECIPIENT

  type account_id

  val load_ledger : int -> int -> t * account_id list
end

module type Input_intf = sig
  module Root_hash : sig
    type t [@@deriving bin_io, compare, hash, sexp, compare, yojson]

    val equal : t -> t -> bool
  end

  module Context : Syncable_ledger.CONTEXT

  module Ledger :
    Ledger_intf
      with type root_hash := Root_hash.t
       and type account_id := Merkle_ledger_tests.Test_stubs.Account_id.t

  module Sync_ledger :
    Syncable_ledger.S
      with type merkle_tree := Ledger.t
       and type hash := Ledger.hash
       and type root_hash := Root_hash.t
       and type addr := Ledger.addr
       and type merkle_path := Ledger.path
       and type account := Ledger.account
       and type query := Ledger.addr Syncable_ledger.Query.t
       and type answer := (Root_hash.t, Ledger.account) Syncable_ledger.Answer.t
end

module Make_context (Subtree_depth : sig
  val sync_ledger_max_subtree_depth : int

  val sync_ledger_default_subtree_depth : int
end) : Syncable_ledger.CONTEXT = struct
  let logger = Logger.null ()

  let ledger_sync_config : Syncable_ledger.daemon_config =
    { max_subtree_depth = Subtree_depth.sync_ledger_max_subtree_depth
    ; default_subtree_depth = Subtree_depth.sync_ledger_default_subtree_depth
    }
end

module Context_subtree_depth32 = Make_context (struct
  let sync_ledger_max_subtree_depth = 3

  let sync_ledger_default_subtree_depth = 2
end)

module Context_subtree_depth81 = Make_context (struct
  let sync_ledger_max_subtree_depth = 8

  let sync_ledger_default_subtree_depth = 1
end)

module Context_subtree_depth82 = Make_context (struct
  let sync_ledger_max_subtree_depth = 8

  let sync_ledger_default_subtree_depth = 2
end)

module Context_subtree_depth86 = Make_context (struct
  let sync_ledger_max_subtree_depth = 8

  let sync_ledger_default_subtree_depth = 6
end)

module Context_subtree_depth88 = Make_context (struct
  let sync_ledger_max_subtree_depth = 8

  let sync_ledger_default_subtree_depth = 8
end)

module Context_subtree_depth68 = Make_context (struct
  let sync_ledger_max_subtree_depth = 6

  let sync_ledger_default_subtree_depth = 8
end)

module Context_subtree_depth80 = Make_context (struct
  let sync_ledger_max_subtree_depth = 8

  let sync_ledger_default_subtree_depth = 0
end)

module Make_test
    (Input : Input_intf) (Input' : sig
      val num_accts : int
    end) =
struct
  open Input
  open Input'
  module Sync_responder = Sync_ledger.Responder

  (* not really kosher but the tests are run in-order, so this will get filled
   * in before we need it. *)
  let total_queries = ref None

  let trust_system = Trust_system.null ()

  let () =
    Async.Scheduler.set_record_backtraces true ;
    Core.Backtrace.elide := false

  let%test "full_sync_entirely_different" =
    let l1, _k1 = Ledger.load_ledger 1 1 in
    let l2, _k2 = Ledger.load_ledger num_accts 2 in
    let desired_root = Ledger.merkle_root l2 in
    let lsync = Sync_ledger.create l1 ~context:(module Context) ~trust_system in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let seen_queries = ref [] in
    let sr =
      Sync_responder.create l2
        (fun q -> seen_queries := q :: !seen_queries)
        ~context:(module Context)
        ~trust_system
    in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:3 qr
         ~f:(fun (root_hash, query) ->
           let%bind answ_or_error =
             Sync_responder.answer_query sr (Envelope.Incoming.local query)
           in
           let answ = Or_error.ok_exn answ_or_error in
           let%bind () =
             if match query with What_contents _ -> true | _ -> false then
               Clock_ns.after
                 (Time_ns.Span.randomize (Time_ns.Span.of_ms 0.2)
                    ~percent:(Percent.of_percentage 20.) )
             else Deferred.unit
           in
           Linear_pipe.write aw (root_hash, query, Envelope.Incoming.local answ) )
      ) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          Sync_ledger.fetch lsync desired_root ~data:() ~equal:(fun () () ->
              true ) )
    with
    | `Ok mt ->
        total_queries := Some (List.length !seen_queries) ;
        Root_hash.equal desired_root (Ledger.merkle_root mt)
    | `Target_changed _ ->
        false

  let%test_unit "new_goal_soon" =
    let l1, _k1 = Ledger.load_ledger num_accts 1 in
    let l2, _k2 = Ledger.load_ledger num_accts 2 in
    let l3, _k3 = Ledger.load_ledger num_accts 3 in
    let desired_root = ref @@ Ledger.merkle_root l2 in
    let lsync = Sync_ledger.create l1 ~context:(module Context) ~trust_system in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let seen_queries = ref [] in
    let sr =
      ref
      @@ Sync_responder.create l2
           (fun q -> seen_queries := q :: !seen_queries)
           ~context:(module Context)
           ~trust_system
    in
    let ctr = ref 0 in
    don't_wait_for
      (Linear_pipe.iter qr ~f:(fun (hash, query) ->
           if not (Root_hash.equal hash !desired_root) then Deferred.unit
           else
             let res =
               if !ctr = (!total_queries |> Option.value_exn) / 2 then (
                 sr :=
                   Sync_responder.create l3
                     (fun q -> seen_queries := q :: !seen_queries)
                     ~context:(module Context)
                     ~trust_system ;
                 desired_root := Ledger.merkle_root l3 ;
                 ignore
                   ( Sync_ledger.new_goal lsync !desired_root ~data:()
                       ~equal:(fun () () -> true)
                     : [ `New | `Repeat | `Update_data ] ) ;
                 Deferred.unit )
               else
                 let%bind answ_or_error =
                   Sync_responder.answer_query !sr
                     (Envelope.Incoming.local query)
                 in
                 let answ = Or_error.ok_exn answ_or_error in
                 Linear_pipe.write aw
                   (!desired_root, query, Envelope.Incoming.local answ)
             in
             ctr := !ctr + 1 ;
             res ) ) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          Sync_ledger.fetch lsync !desired_root ~data:() ~equal:(fun () () ->
              true ) )
    with
    | `Ok _ ->
        failwith "shouldn't happen"
    | `Target_changed _ -> (
        match
          Async.Thread_safe.block_on_async_exn (fun () ->
              Sync_ledger.wait_until_valid lsync !desired_root )
        with
        | `Ok mt ->
            [%test_result: Root_hash.t] ~expect:(Ledger.merkle_root l3)
              (Ledger.merkle_root mt)
        | `Target_changed _ ->
            failwith "the target changed again" )
end

module Make_test_edge_cases (Input : Input_intf) = struct
  open Input
  module Sync_responder = Sync_ledger.Responder

  let trust_system = Trust_system.null ()

  let num_accts = 1026

  let () =
    Async.Scheduler.set_record_backtraces true ;
    Core.Backtrace.elide := false

  let check_answer (query : Ledger.addr Syncable_ledger.Query.t) answer =
    match query with
    | What_child_hashes (_, depth) -> (
        let invalid_depth = depth < 1 in
        match answer with
        | Error s ->
            if
              invalid_depth
              && String.is_substring (Error.to_string_hum s)
                   ~substring:
                     "Invalid depth requested in What_child_hashes request"
            then `Failure_as_expected
            else
              failwithf
                "Expected failure due to invalid subtree depth, returned %s"
                (Error.to_string_hum s) ()
        | Ok a ->
            if invalid_depth then
              failwith
                "Expected failure due to invalid subtree depth, returned a \
                 successful answer"
            else `Answer a )
    | _ ->
        `Answer (Or_error.ok_exn answer)

  let%test "try full_sync_entirely_different with failures" =
    let l1, _k1 = Ledger.load_ledger 1 1 in
    let l2, _k2 = Ledger.load_ledger num_accts 2 in
    let desired_root = Ledger.merkle_root l2 in
    let got_failure_ivar = Ivar.create () in

    let lsync = Sync_ledger.create l1 ~context:(module Context) ~trust_system in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let sr =
      Sync_responder.create l2 ignore ~context:(module Context) ~trust_system
    in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:3 qr
         ~f:(fun (root_hash, query) ->
           let%bind answ_or_error =
             Sync_responder.answer_query sr (Envelope.Incoming.local query)
           in
           match check_answer query answ_or_error with
           | `Answer answ ->
               let%bind () =
                 if match query with What_contents _ -> true | _ -> false then
                   Clock_ns.after
                     (Time_ns.Span.randomize (Time_ns.Span.of_ms 0.2)
                        ~percent:(Percent.of_percentage 20.) )
                 else Deferred.unit
               in
               Linear_pipe.write aw
                 (root_hash, query, Envelope.Incoming.local answ)
           | `Failure_as_expected ->
               Ivar.fill got_failure_ivar true ;
               Deferred.unit ) ) ;
    Async.Thread_safe.block_on_async_exn (fun () ->
        let deferred_res =
          match%map
            Sync_ledger.fetch lsync desired_root ~data:() ~equal:(fun () () ->
                true )
          with
          | `Ok mt ->
              Root_hash.equal desired_root (Ledger.merkle_root mt)
          | `Target_changed _ ->
              false
        in
        Deferred.any [ deferred_res; Ivar.read got_failure_ivar ] )
end

module Make_test_content_length (Input : Input_intf) = struct
  open Input
  module Sync_responder = Sync_ledger.Responder

  let trust_system = Trust_system.null ()

  let num_accts = 1026

  let () =
    Async.Scheduler.set_record_backtraces true ;
    Core.Backtrace.elide := false

  let%test "sync completes despite a mismatched Contents_are answer" =
    let l1, _k1 = Ledger.load_ledger 1 1 in
    let l2, _k2 = Ledger.load_ledger num_accts 2 in
    let desired_root = Ledger.merkle_root l2 in
    let lsync = Sync_ledger.create l1 ~context:(module Context) ~trust_system in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let sr =
      Sync_responder.create l2 ignore ~context:(module Context) ~trust_system
    in
    let adjusted = ref false in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:3 qr
         ~f:(fun (root_hash, query) ->
           let%bind answ_or_error =
             Sync_responder.answer_query sr (Envelope.Incoming.local query)
           in
           let answ = Or_error.ok_exn answ_or_error in
           (* Once, return a Contents_are answer with some extra accounts. *)
           let answ =
             match (query, answ) with
             | ( Syncable_ledger.Query.What_contents _
               , Syncable_ledger.Answer.Contents_are accounts )
               when not !adjusted ->
                 adjusted := true ;
                 Syncable_ledger.Answer.Contents_are
                   (accounts @ List.init 100 ~f:(fun _ -> List.hd_exn accounts))
             | _ ->
                 answ
           in
           Linear_pipe.write aw (root_hash, query, Envelope.Incoming.local answ) )
      ) ;
    Async.Thread_safe.block_on_async_exn (fun () ->
        match%map
          Clock_ns.with_timeout (Time_ns.Span.of_sec 30.)
            (Sync_ledger.fetch lsync desired_root ~data:() ~equal:(fun () () ->
                 true ) )
        with
        | `Result (`Ok mt) ->
            Root_hash.equal desired_root (Ledger.merkle_root mt)
        | `Result (`Target_changed _) ->
            false
        | `Timeout ->
            false )

  let%test "sync completes despite a Contents_are answer with wrong accounts" =
    let l1, _k1 = Ledger.load_ledger 1 1 in
    let l2, _k2 = Ledger.load_ledger num_accts 2 in
    let desired_root = Ledger.merkle_root l2 in
    let lsync = Sync_ledger.create l1 ~context:(module Context) ~trust_system in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let sr =
      Sync_responder.create l2 ignore ~context:(module Context) ~trust_system
    in
    let adjusted = ref false in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:3 qr
         ~f:(fun (root_hash, query) ->
           let%bind answ_or_error =
             Sync_responder.answer_query sr (Envelope.Incoming.local query)
           in
           let answ = Or_error.ok_exn answ_or_error in
           (* Once, return a Contents_are answer of the right length whose
              accounts are all the last one. *)
           let answ =
             match (query, answ) with
             | ( Syncable_ledger.Query.What_contents _
               , Syncable_ledger.Answer.Contents_are (_ :: _ :: _ as accounts) )
               when not !adjusted ->
                 adjusted := true ;
                 Syncable_ledger.Answer.Contents_are
                   (List.map accounts ~f:(fun _ -> List.last_exn accounts))
             | _ ->
                 answ
           in
           Linear_pipe.write aw (root_hash, query, Envelope.Incoming.local answ) )
      ) ;
    Async.Thread_safe.block_on_async_exn (fun () ->
        match%map
          Clock_ns.with_timeout (Time_ns.Span.of_sec 30.)
            (Sync_ledger.fetch lsync desired_root ~data:() ~equal:(fun () () ->
                 true ) )
        with
        | `Result (`Ok mt) ->
            !adjusted && Root_hash.equal desired_root (Ledger.merkle_root mt)
        | `Result (`Target_changed _) ->
            false
        | `Timeout ->
            false )
end

(* A malicious peer can answer a [Num_accounts] sync query with a count whose
   [ceil_log2] exceeds the tree depth. Before the fix, [handle_num_accounts] fed
   that to [complete_with_empties], which starts above the tree height and loops
   effectively forever, hanging the syncer (and this test). The count is now
   range-checked and rejected, the [Num_accounts] query is requeued, and a
   subsequent honest answer lets the sync complete. Instantiated against a single
   healthy context (unlike [Make_test_edge_cases], which also covers degenerate
   subtree depths that legitimately produce failing answers). *)
module Make_test_num_accounts_dos (Input : Input_intf) = struct
  open Input
  module Sync_responder = Sync_ledger.Responder

  let trust_system = Trust_system.null ()

  let num_accts = 20

  let () =
    Async.Scheduler.set_record_backtraces true ;
    Core.Backtrace.elide := false

  let%test "out-of-range num_accounts is rejected without hanging" =
    let l1, _k1 = Ledger.load_ledger 1 1 in
    let l2, _k2 = Ledger.load_ledger num_accts 2 in
    let desired_root = Ledger.merkle_root l2 in
    let lsync = Sync_ledger.create l1 ~context:(module Context) ~trust_system in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let sr =
      Sync_responder.create l2 ignore ~context:(module Context) ~trust_system
    in
    let injected = ref false in
    don't_wait_for
      (Linear_pipe.iter qr ~f:(fun (root_hash, query) ->
           match query with
           | Syncable_ledger.Query.Num_accounts when not !injected ->
               injected := true ;
               Linear_pipe.write aw
                 ( root_hash
                 , query
                 , Envelope.Incoming.local
                     (Syncable_ledger.Answer.Num_accounts
                        (Int.max_value, desired_root) ) )
           | _ ->
               let%bind answ =
                 Sync_responder.answer_query sr (Envelope.Incoming.local query)
               in
               Linear_pipe.write aw
                 ( root_hash
                 , query
                 , Envelope.Incoming.local (Or_error.ok_exn answ) ) ) ) ;
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          Sync_ledger.fetch lsync desired_root ~data:() ~equal:(fun () () ->
              true ) )
    with
    | `Ok mt ->
        Root_hash.equal desired_root (Ledger.merkle_root mt)
    | `Target_changed _ ->
        false
end

module Make_test_target (Input : Input_intf) = struct
  open Input

  let trust_system = Trust_system.null ()

  let%test_unit "target changes before the new target's first query" =
    Async.Thread_safe.block_on_async_exn (fun () ->
        let l1, _k1 = Ledger.load_ledger 1 1 in
        let l2, _k2 = Ledger.load_ledger 2 2 in
        let l3, _k3 = Ledger.load_ledger 3 3 in
        let lsync =
          Sync_ledger.create l1 ~context:(module Context) ~trust_system
        in
        let target = Sync_ledger.target lsync in
        let qr = Sync_ledger.query_reader lsync in
        [%test_eq: Root_hash.t option] (Broadcast_pipe.Reader.peek target) None ;
        let expect_retarget_to h =
          ignore
            ( Sync_ledger.new_goal lsync h ~data:() ~equal:(fun () () -> true)
              : [ `New | `Repeat | `Update_data ] ) ;
          match%map Linear_pipe.read qr with
          | `Ok (root_hash, Syncable_ledger.Query.Num_accounts) ->
              [%test_eq: Root_hash.t] root_hash h ;
              [%test_eq: Root_hash.t option]
                (Broadcast_pipe.Reader.peek target)
                (Some h)
          | `Ok _ ->
              failwith "expected the new target's Num_accounts query"
          | `Eof ->
              failwith "query pipe closed"
        in
        let%bind () = expect_retarget_to (Ledger.merkle_root l2) in
        let%bind () = expect_retarget_to (Ledger.merkle_root l3) in
        let observed =
          Broadcast_pipe.Reader.iter target ~f:(fun _ -> Deferred.unit)
        in
        Sync_ledger.destroy lsync ;
        match%map Async.with_timeout (Time.Span.of_sec 5.) observed with
        | `Result () ->
            ()
        | `Timeout ->
            failwith "target was not closed by destroy" )
end

module Root_hash = struct
  include Merkle_ledger_tests.Test_stubs.Hash

  let to_hash = Fn.id
end

module Base_ledger_inputs = struct
  include Merkle_ledger_tests.Test_stubs
  module Root_hash = Root_hash
end

(* Testing different ledger instantiations on Syncable_ledger *)

module Db = struct
  module Make
      (Context : Syncable_ledger.CONTEXT) (Depth : sig
        val depth : int
      end) =
  struct
    open Merkle_ledger_tests.Test_stubs

    module Root_hash = struct
      include Hash

      let to_hash = Fn.id
    end

    module Location = Merkle_ledger.Location

    module Location_binable = struct
      module Arg = struct
        type t = Location.t =
          | Generic of Mina_stdlib.Bigstring.Stable.Latest.t
          | Account of Location.Addr.Stable.Latest.t
          | Hash of Location.Addr.Stable.Latest.t
        [@@deriving bin_io_unversioned, hash, sexp, compare]
      end

      type t = Arg.t =
        | Generic of Mina_stdlib.Bigstring.t
        | Account of Location.Addr.t
        | Hash of Location.Addr.t
      [@@deriving hash, sexp, compare]

      include Hashable.Make_binable (Arg) [@@deriving
                                            sexp, compare, hash, yojson]
    end

    module Base_ledger_inputs = struct
      include Base_ledger_inputs
      module Location = Location
      module Location_binable = Location_binable
      module Kvdb = In_memory_kvdb
    end

    module Ledger = struct
      include Merkle_ledger.Database.Make (Base_ledger_inputs)

      type hash = Hash.t

      type account = Account.t

      type addr = Addr.t

      let load_ledger num_accounts (balance : int) =
        let ledger = create ~depth:Depth.depth () in
        let account_ids = Account_id.gen_accounts num_accounts in
        let currency_balance = Currency.Balance.of_nanomina_int_exn balance in
        List.iter account_ids ~f:(fun aid ->
            let T = Account_id.eq2 in
            let account = Account.create aid currency_balance in
            ignore
              ( get_or_create_account ledger aid account |> Or_error.ok_exn
                : [ `Added | `Existed ] * Location.t ) ) ;
        (ledger, account_ids)
    end

    module Syncable_ledger_inputs = struct
      module Addr = Ledger.Addr
      module MT = Ledger
      include Base_ledger_inputs

      let account_subtree_height = 6
    end

    module Sync_ledger = Syncable_ledger.Make (Syncable_ledger_inputs)
    module Context = Context
  end

  module DB3 =
    Make
      (Context_subtree_depth32)
      (struct
        let depth = 3
      end)

  module DB16_subtree_depths81 =
    Make
      (Context_subtree_depth81)
      (struct
        let depth = 16
      end)

  module DB16_subtree_depths82 =
    Make
      (Context_subtree_depth82)
      (struct
        let depth = 16
      end)

  module DB16_subtree_depths86 =
    Make
      (Context_subtree_depth86)
      (struct
        let depth = 16
      end)

  module DB16_subtree_depths88 =
    Make
      (Context_subtree_depth88)
      (struct
        let depth = 16
      end)

  module DB16_subtree_depths68 =
    Make
      (Context_subtree_depth68)
      (struct
        let depth = 16
      end)

  module DB16_subtree_depths80 =
    Make
      (Context_subtree_depth80)
      (struct
        let depth = 16
      end)

  module TestDB3_3 =
    Make_test
      (DB3)
      (struct
        let num_accts = 3
      end)

  module TestDB3_8 =
    Make_test
      (DB3)
      (struct
        let num_accts = 8
      end)

  module TestDB16_20 =
    Make_test
      (DB16_subtree_depths86)
      (struct
        let num_accts = 20
      end)

  module TestDB16_Num_accounts_dos =
    Make_test_num_accounts_dos (DB16_subtree_depths86)
  module TestDB16_Target = Make_test_target (DB16_subtree_depths86)

  module TestDB16_1024 =
    Make_test
      (DB16_subtree_depths86)
      (struct
        let num_accts = 1024
      end)

  module TestDB16_1026_subtree_depth81 =
    Make_test
      (DB16_subtree_depths81)
      (struct
        let num_accts = 1026
      end)

  module TestDB16_1026_subtree_depth82 =
    Make_test
      (DB16_subtree_depths82)
      (struct
        let num_accts = 1026
      end)

  module TestDB16_1026_subtree_depth86 =
    Make_test
      (DB16_subtree_depths86)
      (struct
        let num_accts = 1026
      end)

  (*Test till sync_ledger_max_subtree_depth*)
  module TestDB16_1026_subtree_depth88 =
    Make_test
      (DB16_subtree_depths88)
      (struct
        let num_accts = 1026
      end)

  module TestDB16_Edge_Cases_subtree_depth68 =
    Make_test_edge_cases (DB16_subtree_depths68)
  module TestDB16_Edge_Cases_subtree_depth86 =
    Make_test_edge_cases (DB16_subtree_depths81)
  module TestDB16_Edge_Cases_subtree_depth80 =
    Make_test_edge_cases (DB16_subtree_depths80)
  module TestDB16_Content_Length =
    Make_test_content_length (DB16_subtree_depths86)
end

(* Syncing between ledgers that share their first accounts but then diverge,
   as when a node's ledger comes from a fork that lost. *)
module Diverged = struct
  open Db.DB16_subtree_depths86
  open Merkle_ledger_tests.Test_stubs
  module Sync_responder = Sync_ledger.Responder

  let trust_system = Trust_system.null ()

  let build account_ids =
    let ledger = Ledger.create ~depth:16 () in
    List.iter account_ids ~f:(fun account_id ->
        let T = Account_id.eq2 in
        let account =
          Account.create account_id (Currency.Balance.of_nanomina_int_exn 1)
        in
        ignore
          ( Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
            : [ `Added | `Existed ] * Ledger.Location.t ) ) ;
    ledger

  (* Sync [local] to [target], passing each answer through [tamper] first.
     Returns whether the sync completed with the target's root, and the
     errors the responder returned. *)
  let sync ?(tamper = fun _query answer -> answer) ~local ~target () =
    let desired_root = Ledger.merkle_root target in
    let lsync =
      Sync_ledger.create local ~context:(module Context) ~trust_system
    in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let sr =
      Sync_responder.create target ignore
        ~context:(module Context)
        ~trust_system
    in
    let errors = ref [] in
    don't_wait_for
      (Linear_pipe.iter_unordered ~max_concurrency:3 qr
         ~f:(fun (root_hash, query) ->
           match%bind
             Sync_responder.answer_query sr (Envelope.Incoming.local query)
           with
           | Error e ->
               errors := Error.to_string_hum e :: !errors ;
               Deferred.unit
           | Ok answer ->
               Linear_pipe.write aw
                 ( root_hash
                 , query
                 , Envelope.Incoming.local (tamper query answer) ) ) ) ;
    let synced =
      Async.Thread_safe.block_on_async_exn (fun () ->
          match%map
            Clock_ns.with_timeout (Time_ns.Span.of_sec 30.)
              (Sync_ledger.fetch lsync desired_root ~data:()
                 ~equal:(fun () () -> true) )
          with
          | `Result (`Ok mt) ->
              Root_hash.equal desired_root (Ledger.merkle_root mt)
          | `Result (`Target_changed _) | `Timeout ->
              false )
    in
    (synced, !errors)

  let check_synced ~local ~target (synced, errors) =
    assert synced ;
    [%test_eq: string list] [] errors ;
    [%test_eq: int] (Ledger.num_accounts target) (Ledger.num_accounts local)

  let check_absent ledger account_ids =
    List.iter account_ids ~f:(fun account_id ->
        let T = Account_id.eq2 in
        assert (Option.is_none (Ledger.location_of_account ledger account_id)) ;
        match
          Ledger.get_or_create_account ledger account_id
            (Account.create account_id (Currency.Balance.of_nanomina_int_exn 1))
          |> Or_error.ok_exn
        with
        | `Added, _ ->
            ()
        | `Existed, _ ->
            failwith "Account removed by the sync still has a location" )

  let shared = Account_id.gen_accounts 100

  let extra = Account_id.gen_accounts 40

  let%test_unit "sync removes the accounts after the target's last account" =
    let T = Account_id.eq2 in
    let local_only = List.take extra 30 in
    let local = build (shared @ local_only) in
    let target = build shared in
    check_synced ~local ~target (sync ~local ~target ()) ;
    check_absent local local_only

  let%test_unit "sync removes the accounts after the target's last account in \
                 the same subtree" =
    let T = Account_id.eq2 in
    let local_only = List.take extra 5 in
    let local = build (shared @ local_only) in
    let target = build shared in
    check_synced ~local ~target (sync ~local ~target ()) ;
    check_absent local local_only

  let%test_unit "sync removes the accounts that the target replaced" =
    let T = Account_id.eq2 in
    let local_only = List.take extra 3 in
    let target_only = List.sub extra ~pos:3 ~len:3 in
    let local = build (shared @ local_only) in
    let target = build (shared @ target_only) in
    check_synced ~local ~target (sync ~local ~target ()) ;
    check_absent local local_only

  let%test_unit "sync does not depend on the claimed number of accounts" =
    let T = Account_id.eq2 in
    let local = build (shared @ List.take extra 30) in
    let target = build shared in
    (* 70 accounts need a subtree of the same height as 100, so the claim is
       consistent with the target's root and is accepted. *)
    let tamper (query : Ledger.addr Syncable_ledger.Query.t) answer =
      match (query, answer) with
      | Num_accounts, Syncable_ledger.Answer.Num_accounts (_, content_root) ->
          Syncable_ledger.Answer.Num_accounts (70, content_root)
      | _ ->
          answer
    in
    check_synced ~local ~target (sync ~tamper ~local ~target ())

  let%test_unit "sync recovers from an answer with too few accounts" =
    let T = Account_id.eq2 in
    let local = build (List.take shared 1) in
    let target = build (shared @ extra) in
    let tampered = ref false in
    let tamper (query : Ledger.addr Syncable_ledger.Query.t) answer =
      match (query, answer) with
      | ( What_contents _
        , Syncable_ledger.Answer.Contents_are (_ :: _ :: _ as accounts) )
        when not !tampered ->
          tampered := true ;
          Syncable_ledger.Answer.Contents_are (List.drop_last_exn accounts)
      | _ ->
          answer
    in
    let synced, errors = sync ~tamper ~local ~target () in
    assert !tampered ;
    check_synced ~local ~target (synced, errors)
end

(* Answers can arrive for a query the syncer no longer expects: here, one asked
   for the target before the sync switched to another target and back. *)
module Stale_answers = struct
  open Db.DB16_subtree_depths86
  module Sync_responder = Sync_ledger.Responder

  let trust_system = Trust_system.null ()

  (* Sync towards [target_a], holding back the answer to the first query that
     satisfies [hold]. Then switch to another target and back to [target_a],
     answer its account count, deliver the held answer, and finish the sync. *)
  let sync_with_stale_answer ~hold =
    let local, _ = Ledger.load_ledger 1 1 in
    let target_a, _ = Ledger.load_ledger 130 2 in
    let target_b, _ = Ledger.load_ledger 130 3 in
    let root_a = Ledger.merkle_root target_a in
    let root_b = Ledger.merkle_root target_b in
    let lsync =
      Sync_ledger.create local ~context:(module Context) ~trust_system
    in
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let responder =
      Sync_responder.create target_a ignore
        ~context:(module Context)
        ~trust_system
    in
    let answer query =
      let%map answer =
        Sync_responder.answer_query responder (Envelope.Incoming.local query)
      in
      (root_a, query, Envelope.Incoming.local (Or_error.ok_exn answer))
    in
    let read_query () =
      match%map Linear_pipe.read qr with
      | `Ok q ->
          q
      | `Eof ->
          failwith "query pipe closed"
    in
    let set_goal root =
      ignore
        ( Sync_ledger.new_goal lsync root ~data:() ~equal:(fun () () -> true)
          : [ `New | `Repeat | `Update_data ] )
    in
    Async.Thread_safe.block_on_async_exn (fun () ->
        set_goal root_a ;
        (* Answer queries for [target_a] until one is held back. *)
        let rec answer_until_held () =
          let%bind root, query = read_query () in
          if Root_hash.equal root root_a && hold query then answer query
          else
            let%bind a = answer query in
            let%bind () = Linear_pipe.write aw a in
            answer_until_held ()
        in
        let%bind held = answer_until_held () in
        set_goal root_b ;
        set_goal root_a ;
        (* Answer the new account count query for [target_a]. *)
        let rec answer_num_accounts () =
          let%bind root, query = read_query () in
          match query with
          | Num_accounts when Root_hash.equal root root_a ->
              let%bind a = answer query in
              Linear_pipe.write aw a
          | _ ->
              answer_num_accounts ()
        in
        let%bind () = answer_num_accounts () in
        let%bind () = Linear_pipe.write aw held in
        (* Answer every remaining query for [target_a]. *)
        don't_wait_for
          (Linear_pipe.iter qr ~f:(fun (root, query) ->
               if Root_hash.equal root root_a then
                 let%bind a = answer query in
                 Linear_pipe.write aw a
               else Deferred.unit ) ) ;
        match%map
          Clock_ns.with_timeout (Time_ns.Span.of_sec 30.)
            (Sync_ledger.wait_until_valid lsync root_a)
        with
        | `Result (`Ok mt) ->
            Root_hash.equal root_a (Ledger.merkle_root mt)
        | `Result (`Target_changed _) | `Timeout ->
            false )

  let%test "sync ignores a stale answer for an account subtree" =
    sync_with_stale_answer ~hold:(function
      | Syncable_ledger.Query.What_contents _ ->
          true
      | _ ->
          false )

  let%test "sync ignores a stale answer for an inner node" =
    sync_with_stale_answer ~hold:(function
      | Syncable_ledger.Query.What_child_hashes (addr, _) ->
          Ledger.Addr.depth addr > 0
      | _ ->
          false )

  let%test "sync ignores a stale answer for the root" =
    sync_with_stale_answer ~hold:(function
      | Syncable_ledger.Query.What_child_hashes (addr, _) ->
          Ledger.Addr.depth addr = 0
      | _ ->
          false )
end

(* The progress a sync reports as it is given targets and reaches them. *)
module Progress_reporting = struct
  open Db.DB16_subtree_depths86
  module Sync_responder = Sync_ledger.Responder

  let trust_system = Trust_system.null ()

  (* Answer each query from whichever of [targets] has the query's root. *)
  let serve lsync targets =
    let qr = Sync_ledger.query_reader lsync in
    let aw = Sync_ledger.answer_writer lsync in
    let responders =
      List.map targets ~f:(fun target ->
          ( Ledger.merkle_root target
          , Sync_responder.create target ignore
              ~context:(module Context)
              ~trust_system ) )
    in
    don't_wait_for
      (Linear_pipe.iter qr ~f:(fun (root_hash, query) ->
           match
             List.Assoc.find responders root_hash ~equal:Root_hash.equal
           with
           | None ->
               Deferred.unit
           | Some responder ->
               let%bind answer =
                 Sync_responder.answer_query responder
                   (Envelope.Incoming.local query)
               in
               Linear_pipe.write aw
                 ( root_hash
                 , query
                 , Envelope.Incoming.local (Or_error.ok_exn answer) ) ) )

  let sync_to lsync root =
    match
      Async.Thread_safe.block_on_async_exn (fun () ->
          Clock_ns.with_timeout (Time_ns.Span.of_sec 30.)
            (Sync_ledger.fetch lsync root ~data:() ~equal:(fun () () -> true)) )
    with
    | `Result (`Ok _) ->
        ()
    | `Result (`Target_changed _) | `Timeout ->
        failwith "the sync did not reach its target"

  let check_progress lsync ~targets ~synced:expect_synced =
    let { Syncable_ledger.Progress.targets = actual_targets
        ; target_set_at
        ; pending_child_hashes
        ; pending_contents
        ; synced
        } =
      Sync_ledger.progress lsync
    in
    [%test_eq: int] targets actual_targets ;
    [%test_eq: bool] (targets > 0) (Option.is_some target_set_at) ;
    [%test_eq: bool] expect_synced synced ;
    if synced then (
      [%test_eq: int] 0 pending_child_hashes ;
      [%test_eq: int] 0 pending_contents )

  let%test_unit "a sync reports its targets and when it reaches them" =
    let local, _ = Ledger.load_ledger 1 1 in
    let target_a, _ = Ledger.load_ledger 130 2 in
    let target_b, _ = Ledger.load_ledger 130 3 in
    let root_a = Ledger.merkle_root target_a in
    let root_b = Ledger.merkle_root target_b in
    let lsync =
      Sync_ledger.create local ~context:(module Context) ~trust_system
    in
    check_progress lsync ~targets:0 ~synced:false ;
    serve lsync [ target_a; target_b ] ;
    sync_to lsync root_a ;
    check_progress lsync ~targets:1 ~synced:true ;
    ignore
      ( Sync_ledger.new_goal lsync root_b ~data:() ~equal:(fun () () -> true)
        : [ `New | `Repeat | `Update_data ] ) ;
    check_progress lsync ~targets:2 ~synced:false ;
    sync_to lsync root_b ;
    check_progress lsync ~targets:2 ~synced:true
end
