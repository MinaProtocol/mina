open Core
open Async_kernel
open Pipe_lib
open Network_peer

module type Ledger_intf = sig
  include Merkle_ledger.Intf.SYNCABLE

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

    module Location = Merkle_ledger.Location.T

    module Location_binable = struct
      module Arg = struct
        type t = Location.t =
          | Generic of Merkle_ledger.Location.Bigstring.Stable.Latest.t
          | Account of Location.Addr.Stable.Latest.t
          | Hash of Location.Addr.Stable.Latest.t
        [@@deriving bin_io_unversioned, hash, sexp, compare]
      end

      type t = Arg.t =
        | Generic of Merkle_ledger.Location.Bigstring.t
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
end

module Mask = struct
  module Make
      (Context : Syncable_ledger.CONTEXT) (Input : sig
        val depth : int

        val mask_layers : int
      end) =
  struct
    open Merkle_ledger_tests.Test_stubs

    module Root_hash = struct
      include Hash

      let to_hash = Fn.id
    end

    module Maskable_and_mask =
      Merkle_ledger_tests.Test_mask.Make_maskable_and_mask_with_depth (Input)

    module Ledger = struct
      open Merkle_ledger_tests.Test_stubs
      module Base_db = Maskable_and_mask.Base_db
      module Any_base = Maskable_and_mask.Any_base
      module Base = Any_base.M
      module Mask = Maskable_and_mask.Mask
      module Maskable = Maskable_and_mask.Maskable
      include Mask.Attached

      (* Each account for a layer of a mask will all have the same balance.
         Specifically, the base maskable layer will have a balance of
         `balance`. For all of the accounts of a mask at layer n with balance
         `b`, all of the accounts at layer n + 1 will have a balance of `2 * b` *)
      let load_ledger num_accounts (balance : int) : t * 'a =
        let db = Base_db.create ~depth:Input.depth () in
        let maskable = Any_base.cast (module Base_db) db in
        let account_ids = Account_id.gen_accounts num_accounts in
        let initial_balance_multiplier =
          Int.pow 2 Input.mask_layers * balance
        in
        List.iter account_ids ~f:(fun account_id ->
            let account =
              Account.create account_id
                (Currency.Balance.of_nanomina_int_exn
                   (initial_balance_multiplier * 2) )
            in
            let action, _ =
              Maskable.get_or_create_account maskable account_id account
              |> Or_error.ok_exn
            in
            assert ([%equal: [ `Added | `Existed ]] action `Added) ) ;
        let mask = Mask.create ~depth:Input.depth () in
        let attached_mask = Maskable.register_mask maskable mask in
        (* On the mask, all the children will have different values *)
        let rec construct_layered_masks iter child_balance parent_mask =
          if Int.equal iter 0 then (
            assert (Int.equal balance child_balance) ;
            parent_mask )
          else
            let parent_base =
              Any_base.cast (module Mask.Attached) parent_mask
            in
            let child_mask = Mask.create ~depth:Input.depth () in
            let attached_mask = Maskable.register_mask parent_base child_mask in
            List.iter account_ids ~f:(fun account_id ->
                let account =
                  Account.create account_id
                    (Currency.Balance.of_nanomina_int_exn child_balance)
                in
                let action, location =
                  Mask.Attached.get_or_create_account attached_mask account_id
                    account
                  |> Or_error.ok_exn
                in
                match action with
                | `Existed ->
                    Mask.Attached.set attached_mask location account
                | `Added ->
                    failwith "Expected to re-use an existing account" ) ;
            construct_layered_masks (iter - 1) (child_balance / 2) attached_mask
        in
        ( construct_layered_masks Input.mask_layers initial_balance_multiplier
            attached_mask
        , account_ids )

      type addr = Addr.t

      type account = Account.t

      type hash = Hash.t
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

  module Mask3_Layer1 =
    Make
      (Context_subtree_depth32)
      (struct
        let depth = 3

        let mask_layers = 1
      end)

  module Mask16_Layer1 =
    Make
      (Context_subtree_depth32)
      (struct
        let depth = 16

        let mask_layers = 1
      end)

  module Mask16_Layer2 =
    Make
      (Context_subtree_depth32)
      (struct
        let depth = 16

        let mask_layers = 2
      end)

  module Mask16_Layer2_Depth81 =
    Make
      (Context_subtree_depth81)
      (struct
        let depth = 16

        let mask_layers = 2
      end)

  module Mask16_Layer2_Depth86 =
    Make
      (Context_subtree_depth86)
      (struct
        let depth = 16

        let mask_layers = 2
      end)

  module Mask16_Layer2_Depth88 =
    Make
      (Context_subtree_depth88)
      (struct
        let depth = 16

        let mask_layers = 2
      end)

  module Mask16_Layer2_Depth68 =
    Make
      (Context_subtree_depth68)
      (struct
        let depth = 16

        let mask_layers = 2
      end)

  module Mask16_Layer2_Depth80 =
    Make
      (Context_subtree_depth80)
      (struct
        let depth = 16

        let mask_layers = 2
      end)

  module TestMask3_Layer1_3 =
    Make_test
      (Mask3_Layer1)
      (struct
        let num_accts = 3
      end)

  module TestMask3_Layer1_8 =
    Make_test
      (Mask3_Layer1)
      (struct
        let num_accts = 8
      end)

  module TestMask16_Layer1_20 =
    Make_test
      (Mask16_Layer1)
      (struct
        let num_accts = 20
      end)

  module TestMask16_Layer1_1024 =
    Make_test
      (Mask16_Layer1)
      (struct
        let num_accts = 1024
      end)

  module TestMask16_Layer2_20 =
    Make_test
      (Mask16_Layer2)
      (struct
        let num_accts = 20
      end)

  module TestMask16_Layer2_1024 =
    Make_test
      (Mask16_Layer2)
      (struct
        let num_accts = 1024
      end)

  module TestMask16_Layer2_1024_Depth81 =
    Make_test
      (Mask16_Layer2_Depth81)
      (struct
        let num_accts = 1024
      end)

  module TestMask16_Layer2_1024_Depth86 =
    Make_test
      (Mask16_Layer2_Depth86)
      (struct
        let num_accts = 1024
      end)

  module TestMask16_Layer2_1024_Depth88 =
    Make_test
      (Mask16_Layer2_Depth88)
      (struct
        let num_accts = 1024
      end)

  module TestMask16_Edge_Cases_Depth68 =
    Make_test_edge_cases (Mask16_Layer2_Depth68)
  module TestMask16_Edge_Cases_Depth81 =
    Make_test_edge_cases (Mask16_Layer2_Depth81)
  module TestMask16_Edge_Cases_Depth80 =
    Make_test_edge_cases (Mask16_Layer2_Depth80)
end
