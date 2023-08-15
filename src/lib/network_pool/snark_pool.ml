open Core_kernel
open Async
open Pipe_lib
open Network_peer

module Snark_tables = struct
  type t =
    { all :
        Ledger_proof.t One_or_two.t Priced_proof.t
        Transaction_snark_work.Statement.Map.t
    ; rebroadcastable :
        (Ledger_proof.t One_or_two.t Priced_proof.t * Core.Time.t)
        Transaction_snark_work.Statement.Map.t
    }
  [@@deriving sexp, equal]
end

module type S = sig
  type transition_frontier

  module Resource_pool : sig
    include
      Intf.Snark_resource_pool_intf
        with type transition_frontier := transition_frontier

    val remove_solved_work : t -> Transaction_snark_work.Statement.t -> unit

    module Diff : Intf.Snark_pool_diff_intf with type resource_pool := t
  end

  module For_tests : sig
    val get_rebroadcastable :
         Resource_pool.t
      -> has_timed_out:(Time.t -> [ `Timed_out | `Ok ])
      -> Resource_pool.Diff.t list
  end

  include
    Intf.Network_pool_base_intf
      with type resource_pool := Resource_pool.t
       and type resource_pool_diff := Resource_pool.Diff.t
       and type resource_pool_diff_verified := Resource_pool.Diff.t
       and type transition_frontier := transition_frontier
       and type config := Resource_pool.Config.t
       and type transition_frontier_diff :=
        Resource_pool.transition_frontier_diff
       and type rejected_diff := Resource_pool.Diff.rejected

  val get_completed_work :
       t
    -> Transaction_snark_work.Statement.t
    -> Transaction_snark_work.Checked.t option
end

module type Transition_frontier_intf = sig
  type t

  type staged_ledger

  module Breadcrumb : sig
    type t

    val staged_ledger : t -> staged_ledger
  end

  type best_tip_diff

  val best_tip : t -> Breadcrumb.t

  val best_tip_diff_pipe : t -> best_tip_diff Broadcast_pipe.Reader.t

  val snark_pool_refcount_pipe :
       t
    -> Transition_frontier.Extensions.Snark_pool_refcount.view
       Pipe_lib.Broadcast_pipe.Reader.t

  val work_is_referenced : t -> Transaction_snark_work.Statement.t -> bool

  val best_tip_table : t -> Transaction_snark_work.Statement.Set.t
end

module Make
    (Base_ledger : Intf.Base_ledger_intf) (Staged_ledger : sig
      type t

      val ledger : t -> Base_ledger.t
    end)
    (Transition_frontier : Transition_frontier_intf
                             with type staged_ledger := Staged_ledger.t) =
struct
  module Resource_pool = struct
    module T = struct
      let label = "snark_pool"

      module Config = struct
        type t =
          { trust_system : (Trust_system.t[@sexp.opaque])
          ; verifier : (Verifier.t[@sexp.opaque])
          ; disk_location : string
          }
        [@@deriving sexp, make]
      end

      type transition_frontier_diff =
        [ `Refcount_update of Extensions.Snark_pool_refcount.view
        | `New_best_tip of Base_ledger.t ]

      type t =
        { snark_tables : Snark_tables.t ref
        ; frontier : (unit -> Transition_frontier.t option[@sexp.opaque])
        ; config : Config.t
        ; logger : (Logger.t[@sexp.opaque])
        ; account_creation_fee : Currency.Fee.t
        ; batcher : Batcher.Snark_pool.t
        }
      [@@deriving sexp]

      let make_config = Config.make

      let best_tip_ledger t =
        t.frontier ()
        |> Option.map ~f:(fun tf ->
               Transition_frontier.best_tip tf
               |> Transition_frontier.Breadcrumb.staged_ledger
               |> Staged_ledger.ledger )

      let best_tip_table t =
        t.frontier () |> Option.map ~f:Transition_frontier.best_tip_table

      let work_is_referenced t work =
        t.frontier ()
        |> Option.value_map ~default:false ~f:(fun tf ->
               Transition_frontier.work_is_referenced tf work )

      let snark_pool_json t : Yojson.Safe.t =
        `List
          (Map.fold ~init:[] !(t.snark_tables).all
             ~f:(fun ~key ~data:{ proof = _; fee = { fee; prover } } acc ->
               let work_ids =
                 Transaction_snark_work.Statement.compact_json key
               in
               `Assoc
                 [ ("work_ids", work_ids)
                 ; ("fee", Currency.Fee.Stable.V1.to_yojson fee)
                 ; ( "prover"
                   , Signature_lib.Public_key.Compressed.Stable.V1.to_yojson
                       prover )
                 ]
               :: acc ) )

      let all_completed_work (t : t) : Transaction_snark_work.Info.t list =
        Map.fold ~init:[] !(t.snark_tables).all
          ~f:(fun ~key ~data:{ proof = _; fee = { fee; prover } } acc ->
            let work_ids = Transaction_snark_work.Statement.work_ids key in
            { Transaction_snark_work.Info.statements = key
            ; work_ids
            ; fee
            ; prover
            }
            :: acc )

      let fee_is_sufficient t ~fee ~account_exists =
        Currency.Fee.(fee >= t.account_creation_fee) || account_exists

      let handle_new_best_tip_ledger t ledger =
        let open Mina_base in
        let open Signature_lib in
        let account_ids =
          !(t.snark_tables).all |> Map.data
          |> List.map ~f:(fun { Priced_proof.fee = { prover; _ }; _ } ->
                 prover )
          |> List.dedup_and_sort ~compare:Public_key.Compressed.compare
          |> List.map ~f:(fun prover ->
                 (prover, Account_id.create prover Token_id.default) )
          |> Public_key.Compressed.Map.of_alist_exn
        in
        (* if this is still starving the scheduler, we can make `location_of_account_batch` yield while it traverses the masks *)
        let account_locations =
          account_ids |> Map.data
          |> Base_ledger.location_of_account_batch ledger
          |> Account_id.Map.of_alist_exn
        in
        Map.iteri !(t.snark_tables).all
          ~f:(fun ~key ~data:{ fee = { fee; prover }; _ } ->
            let account_exists =
              prover |> Map.find_exn account_ids
              |> Map.find_exn account_locations
              |> Option.is_some
            in
            let keep = fee_is_sufficient t ~fee ~account_exists in
            if not keep then
              t.snark_tables :=
                { all = Map.remove !(t.snark_tables).all key
                ; rebroadcastable =
                    Map.remove !(t.snark_tables).rebroadcastable key
                } )

      let handle_refcount_update t
          ({ removed_work } : Extensions.Snark_pool_refcount.view) =
        [%log' trace t.logger]
          "Handling snark refcount table: $num_removed works were removed"
          ~metadata:[ ("num_removed", `Int (List.length removed_work)) ] ;
        t.snark_tables :=
          { all =
              List.fold ~init:!(t.snark_tables).all ~f:Map.remove removed_work
          ; rebroadcastable =
              List.fold ~init:!(t.snark_tables).rebroadcastable ~f:Map.remove
                removed_work
          } ;
        Mina_metrics.(
          Gauge.set Snark_work.snark_pool_size
            (Float.of_int @@ Map.length !(t.snark_tables).all))

      let handle_transition_frontier_diff u t =
        match u with
        | `New_best_tip ledger ->
            O1trace.sync_thread "apply_new_best_tip_ledger_to_snark_pool"
              (fun () -> handle_new_best_tip_ledger t ledger)
        | `Refcount_update refcount_update ->
            O1trace.sync_thread "apply_refcount_update_to_snark_pool" (fun () ->
                handle_refcount_update t refcount_update )

      (*TODO? add referenced statements from the transition frontier to ref_table here otherwise the work referenced in the root and not in any of the successor blocks will never be included. This may not be required because the chances of a new block from the root is very low (root's existing successor is 1 block away from finality)*)
      let listen_to_frontier_broadcast_pipe frontier_broadcast_pipe
          ~tf_diff_writer =
        let tf_deferred =
          Broadcast_pipe.Reader.iter frontier_broadcast_pipe ~f:(function
            | Some tf ->
                (* Start the count at the max so we flush after reconstructing
                   the transition_frontier *)
                Broadcast_pipe.Reader.iter
                  (Transition_frontier.snark_pool_refcount_pipe tf) ~f:(fun x ->
                    Strict_pipe.Writer.write tf_diff_writer (`Refcount_update x) )
                |> Deferred.don't_wait_for ;
                Broadcast_pipe.Reader.iter
                  (Transition_frontier.best_tip_diff_pipe tf) ~f:(fun _ ->
                    Strict_pipe.Writer.write tf_diff_writer
                      (`New_best_tip
                        ( Transition_frontier.best_tip tf
                        |> Transition_frontier.Breadcrumb.staged_ledger
                        |> Staged_ledger.ledger ) ) )
                |> Deferred.don't_wait_for ;
                return ()
            | None ->
                return () )
        in
        Deferred.don't_wait_for tf_deferred

      let create ~constraint_constants ~consensus_constants:_ ~time_controller:_
          ~frontier_broadcast_pipe ~config ~logger ~tf_diff_writer =
        let t =
          { snark_tables =
              ref
                { Snark_tables.all = Transaction_snark_work.Statement.Map.empty
                ; rebroadcastable = Transaction_snark_work.Statement.Map.empty
                }
          ; frontier =
              (fun () -> Broadcast_pipe.Reader.peek frontier_broadcast_pipe)
          ; batcher = Batcher.Snark_pool.create config.verifier
          ; logger
          ; config
          ; account_creation_fee =
              constraint_constants
                .Genesis_constants.Constraint_constants.account_creation_fee
          }
        in
        listen_to_frontier_broadcast_pipe frontier_broadcast_pipe
          ~tf_diff_writer ;
        t

      let get_logger t = t.logger

      let request_proof t = Map.find !(t.snark_tables).all

      let add_snark ?(is_local = false) t ~work
          ~(proof : Ledger_proof.t One_or_two.t) ~fee =
        if work_is_referenced t work then (
          (*Note: fee against existing proofs and the new proofs are checked in
            Diff.unsafe_apply which calls this function*)
          t.snark_tables :=
            { all = Map.set !(t.snark_tables).all ~key:work ~data:{ proof; fee }
            ; rebroadcastable =
                ( if is_local then
                  Map.set !(t.snark_tables).rebroadcastable ~key:work
                    ~data:({ proof; fee }, Time.now ())
                else
                  (* Stop rebroadcasting locally generated snarks if they are
                     overwritten. No-op if there is no rebroadcastable SNARK with that
                     statement. *)
                  Map.remove !(t.snark_tables).rebroadcastable work )
            } ;
          (*when snark work is added to the pool*)
          Mina_metrics.(
            Gauge.set Snark_work.useful_snark_work_received_time_sec
              Time.(
                let x = now () |> to_span_since_epoch |> Span.to_sec in
                x -. Mina_metrics.time_offset_sec) ;
            Gauge.set Snark_work.snark_pool_size
              (Float.of_int @@ Map.length !(t.snark_tables).all) ;
            Snark_work.Snark_fee_histogram.observe Snark_work.snark_fee
              ( fee.Mina_base.Fee_with_prover.fee
              |> Currency.Fee.to_nanomina_int |> Float.of_int )) ;
          `Added )
        else
          let origin = if is_local then "locally generated" else "gossiped" in
          [%log' warn t.logger]
            "Rejecting %s snark work $stmt, statement not referenced" origin
            ~metadata:
              [ ( "stmt"
                , One_or_two.to_yojson Transaction_snark.Statement.to_yojson
                    work )
              ] ;
          `Statement_not_referenced

      let verify_and_act t ~work ~sender =
        let statements, priced_proof = work in
        let { Priced_proof.proof = proofs; fee = { prover; fee } } =
          priced_proof
        in
        let trust_record =
          Trust_system.record_envelope_sender t.config.trust_system t.logger
            sender
        in
        let is_local = Envelope.Sender.(equal Local sender) in
        let metadata =
          [ ("prover", Signature_lib.Public_key.Compressed.to_yojson prover)
          ; ("fee", Currency.Fee.to_yojson fee)
          ; ("sender", Envelope.Sender.to_yojson sender)
          ]
        in
        let log_and_punish ?(punish = true) statement e =
          let metadata =
            [ ("error", Error_json.error_to_yojson e)
            ; ("work_id", `Int (Transaction_snark.Statement.hash statement))
            ]
            @ metadata
          in
          [%log' error t.logger] ~metadata
            "Error verifying transaction snark from $sender: $error" ;
          if punish && not is_local then
            trust_record
              ( Trust_system.Actions.Sent_invalid_proof
              , Some ("Error verifying transaction snark: $error", metadata) )
          else Deferred.return ()
        in
        let message = Mina_base.Sok_message.create ~fee ~prover in
        let verify proofs =
          let open Deferred.Let_syntax in
          let%bind statement_check =
            One_or_two.Deferred_result.map proofs ~f:(fun (p, s) ->
                let proof_statement = Ledger_proof.statement p in
                if Transaction_snark.Statement.( = ) proof_statement s then
                  Deferred.Or_error.ok_unit
                else
                  let e = Error.of_string "Statement and proof do not match" in
                  if is_local then
                    [%log' debug t.logger] ~metadata
                      !"Statement and proof mismatch. Proof statement: \
                        %{sexp:Transaction_snark.Statement.t} Statement \
                        %{sexp: Transaction_snark.Statement.t}"
                      proof_statement s ;
                  let%map () = log_and_punish s e in
                  Error e )
          in
          let work = One_or_two.map proofs ~f:snd in
          let account_opt =
            let open Mina_base in
            let open Option.Let_syntax in
            let%bind ledger = best_tip_ledger t in
            if Deferred.is_determined (Base_ledger.detached_signal ledger) then
              None
            else
              let%bind loc =
                Account_id.create prover Token_id.default
                |> Base_ledger.location_of_account ledger
              in
              Base_ledger.get ledger loc
          in
          let prover_account_exists = Option.is_some account_opt in
          let prover_permitted_to_receive =
            let open Option.Let_syntax in
            let%map account = account_opt in
            Mina_base.Account.has_permission
              ~control:Mina_base.Control.Tag.None_given ~to_:`Access account
            && Mina_base.Account.has_permission
                 ~control:Mina_base.Control.Tag.None_given ~to_:`Receive account
          in
          if
            not (fee_is_sufficient t ~fee ~account_exists:prover_account_exists)
          then (
            [%log' debug t.logger]
              "Snark work did not have sufficient fee to create prover $prover \
               acccount"
              ~metadata ;
            return false )
          else if
            Option.value_map ~default:false ~f:not prover_permitted_to_receive
          then (
            [%log' warn t.logger]
              "Snark work prover $prover not permitted to receive fees. \
               Required permission to receive is $receive_permission"
              ~metadata:
                ( ( "receive_permission"
                  , Mina_base.Permissions.Auth_required.to_yojson
                      (Option.value_map account_opt
                         ~default:Mina_base.Permissions.user_default
                         ~f:(fun (a : Mina_base.Account.t) -> a.permissions) )
                        .receive )
                :: metadata ) ;
            return false )
          else if not (work_is_referenced t work) then (
            [%log' debug t.logger] "Work $stmt not referenced"
              ~metadata:
                ( ( "stmt"
                  , One_or_two.to_yojson Transaction_snark.Statement.to_yojson
                      work )
                :: metadata ) ;
            return false )
          else
            match statement_check with
            | Error _ ->
                return false
            | Ok _ -> (
                let log ?punish e =
                  Deferred.List.iter (One_or_two.to_list proofs)
                    ~f:(fun (_, s) -> log_and_punish ?punish s e)
                in
                let proof_env =
                  Envelope.Incoming.wrap
                    ~data:(One_or_two.map proofs ~f:fst, message)
                    ~sender
                in
                match Signature_lib.Public_key.decompress prover with
                | None ->
                    (* We may need to decompress the key when paying the fee
                       transfer, so check that we can do it now.
                    *)
                    [%log' error t.logger]
                      "Proof had an invalid key: $public_key"
                      ~metadata:
                        [ ( "public_key"
                          , Signature_lib.Public_key.Compressed.to_yojson prover
                          )
                        ] ;
                    Deferred.return false
                | Some _ -> (
                    match%bind
                      Batcher.Snark_pool.verify t.batcher proof_env
                    with
                    | Ok true ->
                        return true
                    | Ok false ->
                        (* if this proof is in the set of invalid proofs*)
                        let e = Error.of_string "Invalid proof" in
                        let%map () = log e in
                        false
                    | Error e ->
                        (* Verifier crashed or other errors at our end. Don't punish the peer*)
                        let%map () = log ~punish:false e in
                        false ) )
        in
        match One_or_two.zip proofs statements with
        | Ok pairs ->
            verify pairs
        | Error e ->
            [%log' error t.logger]
              ~metadata:
                ( [ ("error", Error_json.error_to_yojson e)
                  ; ( "work_ids"
                    , Transaction_snark_work.Statement.compact_json statements
                    )
                  ]
                @ metadata )
              "One_or_two length mismatch: $error" ;
            Deferred.return false
    end

    include T
    module Diff = Snark_pool_diff.Make (Transition_frontier) (T)

    (** Returns locally-generated snark work for re-broadcast.
        This is limited to recent work which is yet to appear in a block.
    *)
    let get_rebroadcastable t ~has_timed_out:_ =
      match best_tip_table t with
      | None ->
          []
      | Some best_tips ->
          Map.to_alist !(t.snark_tables).rebroadcastable
          |> List.filter_map ~f:(fun (stmt, (snark, _time)) ->
                 if Set.mem best_tips stmt then
                   Some (Diff.Add_solved_work (stmt, snark))
                 else None )

    let remove_solved_work t work =
      t.snark_tables :=
        { all = Map.remove !(t.snark_tables).all work
        ; rebroadcastable = Map.remove !(t.snark_tables).rebroadcastable work
        }
  end

  include Network_pool_base.Make (Transition_frontier) (Resource_pool)

  module For_tests = struct
    let get_rebroadcastable = Resource_pool.get_rebroadcastable
  end

  let get_completed_work t statement =
    Option.map
      (Resource_pool.request_proof (resource_pool t) statement)
      ~f:(fun Priced_proof.{ proof; fee = { fee; prover } } ->
        Transaction_snark_work.Checked.create_unsafe
          { Transaction_snark_work.fee; proofs = proof; prover } )
end

(* TODO: defunctor or remove monkey patching (#3731) *)
include
  Make (Mina_ledger.Ledger) (Staged_ledger)
    (struct
      include Transition_frontier

      type best_tip_diff = Extensions.Best_tip_diff.view

      let best_tip_diff_pipe t =
        Extensions.(get_view_pipe (extensions t) Best_tip_diff)

      let snark_pool_refcount_pipe t =
        Extensions.(get_view_pipe (extensions t) Snark_pool_refcount)

      let snark_pool_refcount t =
        Extensions.(get_extension (extensions t) Snark_pool_refcount)

      let work_is_referenced t =
        Extensions.Snark_pool_refcount.work_is_referenced
          (snark_pool_refcount t)

      let best_tip_table t =
        Extensions.Snark_pool_refcount.best_tip_table (snark_pool_refcount t)
    end)

module Diff_versioned = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = Resource_pool.Diff.t =
        | Add_solved_work of
            Transaction_snark_work.Statement.Stable.V2.t
            * Ledger_proof.Stable.V2.t One_or_two.Stable.V1.t
              Priced_proof.Stable.V1.t
        | Empty
      [@@deriving compare, sexp, to_yojson, hash]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    | Add_solved_work of
        Transaction_snark_work.Statement.t
        * Ledger_proof.t One_or_two.t Priced_proof.t
    | Empty
  [@@deriving compare, sexp, to_yojson, hash]
end

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs

let%test_module "random set test" =
  ( module struct
    open Mina_base

    let trust_system = Mocks.trust_system

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    (* SNARK work is rejected if the prover doesn't have an account and the fee
       is below the account creation fee. So, just to make generating valid SNARK
       work easier for testing, we set the account creation fee to 0. *)
    let constraint_constants =
      { precomputed_values.constraint_constants with
        account_creation_fee = Currency.Fee.zero
      }

    let consensus_constants = precomputed_values.consensus_constants

    let proof_level = precomputed_values.proof_level

    let logger = Logger.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ())
            () )

    module Mock_snark_pool =
      Make (Mocks.Base_ledger) (Mocks.Staged_ledger) (Mocks.Transition_frontier)
    open Ledger_proof.For_tests

    let apply_diff resource_pool work
        ?(proof = One_or_two.map ~f:mk_dummy_proof)
        ?(sender = Envelope.Sender.Local) fee =
      let diff =
        Mock_snark_pool.Resource_pool.Diff.Add_solved_work
          (work, { Priced_proof.Stable.Latest.proof = proof work; fee })
      in
      let enveloped_diff = Envelope.Incoming.wrap ~data:diff ~sender in
      match%map
        Mock_snark_pool.Resource_pool.Diff.verify resource_pool enveloped_diff
      with
      | Ok _ ->
          Mock_snark_pool.Resource_pool.Diff.unsafe_apply resource_pool
            enveloped_diff
      | Error _ ->
          Error (`Other (Error.of_string "Invalid diff"))

    let config =
      Mock_snark_pool.Resource_pool.make_config ~verifier ~trust_system
        ~disk_location:"/tmp/snark-pool"

    let gen ?length () =
      let open Quickcheck.Generator.Let_syntax in
      let gen_entry =
        Quickcheck.Generator.tuple2 Mocks.Transaction_snark_work.Statement.gen
          Fee_with_prover.gen
      in
      let%map sample_solved_work =
        match length with
        | None ->
            Quickcheck.Generator.list gen_entry
        | Some n ->
            Quickcheck.Generator.list_with_length n gen_entry
      in
      let tf = Mocks.Transition_frontier.create [] in
      let frontier_broadcast_pipe_r, _ = Broadcast_pipe.create (Some tf) in
      let open Deferred.Let_syntax in
      let mock_pool, _r_sink, _l_sink =
        Mock_snark_pool.create ~config ~logger ~constraint_constants
          ~consensus_constants ~time_controller
          ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
          ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
        (* |>  *)
      in
      let pool = Mock_snark_pool.resource_pool mock_pool in
      (*Statements should be referenced before work for those can be included*)
      let%bind () =
        Mocks.Transition_frontier.refer_statements tf
          (List.unzip sample_solved_work |> fst)
      in
      let%map () =
        Deferred.List.iter sample_solved_work ~f:(fun (work, fee) ->
            let%map res = apply_diff pool work fee in
            assert (Result.is_ok res) )
      in
      (pool, tf)

    let%test_unit "Invalid proofs are not accepted" =
      let open Quickcheck.Generator.Let_syntax in
      let invalid_work_gen =
        let gen =
          let gen_entry =
            Quickcheck.Generator.tuple3
              Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
              Signature_lib.Public_key.Compressed.gen
          in
          let%map solved_work = Quickcheck.Generator.list gen_entry in
          List.fold ~init:[] solved_work
            ~f:(fun acc (work, fee, some_other_pk) ->
              (*Making it invalid by forging*)
              let invalid_sok_digest =
                Sok_message.(
                  digest @@ create ~prover:some_other_pk ~fee:fee.fee)
              in
              ( work
              , One_or_two.map work ~f:(fun statement ->
                    Ledger_proof.create ~statement
                      ~sok_digest:invalid_sok_digest
                      ~proof:Proof.transaction_dummy )
              , fee
              , some_other_pk )
              :: acc )
        in
        Quickcheck.Generator.filter gen ~f:(fun ls ->
            List.for_all ls ~f:(fun (_, _, fee, mal_pk) ->
                not
                @@ Signature_lib.Public_key.Compressed.equal mal_pk fee.prover ) )
      in
      Quickcheck.test ~trials:5
        ~sexp_of:
          [%sexp_of:
            (Mock_snark_pool.Resource_pool.t * Mocks.Transition_frontier.t)
            Deferred.t
            * ( Transaction_snark_work.Statement.t
              * Ledger_proof.t One_or_two.t
              * Fee_with_prover.t
              * Signature_lib.Public_key.Compressed.t )
              list]
        (Quickcheck.Generator.tuple2 (gen ()) invalid_work_gen)
        ~f:(fun (t, invalid_work_lst) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let open Deferred.Let_syntax in
              let%bind t, tf = t in
              let completed_works =
                Mock_snark_pool.Resource_pool.all_completed_work t
              in
              (*Statements should be referenced before work for those can be included*)
              let%bind () =
                Mocks.Transition_frontier.refer_statements tf
                  (List.map invalid_work_lst ~f:(fun (stmt, _, _, _) -> stmt))
              in
              let%map () =
                Deferred.List.iter invalid_work_lst
                  ~f:(fun (statements, proofs, fee, _) ->
                    let diff =
                      Mock_snark_pool.Resource_pool.Diff.Add_solved_work
                        ( statements
                        , { Priced_proof.Stable.Latest.proof = proofs; fee } )
                      |> Envelope.Incoming.local
                    in
                    let%map res =
                      Mock_snark_pool.Resource_pool.Diff.verify t diff
                    in
                    assert (Result.is_error res) )
              in
              [%test_eq: Transaction_snark_work.Info.t list] completed_works
                (Mock_snark_pool.Resource_pool.all_completed_work t) ) )

    let%test_unit "When two priced proofs of the same work are inserted into \
                   the snark pool, the fee of the work is at most the minimum \
                   of those fees" =
      Quickcheck.test ~trials:5
        ~sexp_of:
          [%sexp_of:
            (Mock_snark_pool.Resource_pool.t * Mocks.Transition_frontier.t)
            Deferred.t
            * Mocks.Transaction_snark_work.Statement.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Async.Quickcheck.Generator.tuple4 (gen ())
           Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
           Fee_with_prover.gen )
        ~f:(fun (t, work, fee_1, fee_2) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind t, tf = t in
              (*Statements should be referenced before work for those can be included*)
              let%bind () =
                Mocks.Transition_frontier.refer_statements tf [ work ]
              in
              let%bind _ = apply_diff t work fee_1 in
              let%map _ = apply_diff t work fee_2 in
              let fee_upper_bound = Currency.Fee.min fee_1.fee fee_2.fee in
              let { Priced_proof.fee = { fee; _ }; _ } =
                Option.value_exn
                  (Mock_snark_pool.Resource_pool.request_proof t work)
              in
              assert (Currency.Fee.(fee <= fee_upper_bound)) ) )

    let%test_unit "A priced proof of a work will replace an existing priced \
                   proof of the same work only if it's fee is smaller than the \
                   existing priced proof" =
      Quickcheck.test ~trials:5
        ~sexp_of:
          [%sexp_of:
            (Mock_snark_pool.Resource_pool.t * Mocks.Transition_frontier.t)
            Deferred.t
            * Mocks.Transaction_snark_work.Statement.t
            * Fee_with_prover.t
            * Fee_with_prover.t]
        (Quickcheck.Generator.tuple4 (gen ())
           Mocks.Transaction_snark_work.Statement.gen Fee_with_prover.gen
           Fee_with_prover.gen )
        ~f:(fun (t, work, fee_1, fee_2) ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              let%bind t, tf = t in
              (*Statements should be referenced before work for those can be included*)
              let%bind () =
                Mocks.Transition_frontier.refer_statements tf [ work ]
              in
              Mock_snark_pool.Resource_pool.remove_solved_work t work ;
              let expensive_fee = Fee_with_prover.max fee_1 fee_2
              and cheap_fee = Fee_with_prover.min fee_1 fee_2 in
              let%bind _ = apply_diff t work cheap_fee in
              let%map res = apply_diff t work expensive_fee in
              assert (Result.is_error res) ;
              assert (
                Currency.Fee.equal cheap_fee.fee
                  (Option.value_exn
                     (Mock_snark_pool.Resource_pool.request_proof t work) )
                    .fee
                    .fee ) ) )

    let fake_work =
      `One
        (Quickcheck.random_value ~seed:(`Deterministic "worktest")
           Transaction_snark.Statement.gen )

    let%test_unit "Work that gets fed into apply_and_broadcast will be \
                   received in the pool's reader" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let frontier_broadcast_pipe_r, _ =
            Broadcast_pipe.create (Some (Mocks.Transition_frontier.create []))
          in
          let network_pool, _, _ =
            Mock_snark_pool.create ~config ~constraint_constants
              ~consensus_constants ~time_controller ~logger
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
              ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
          in
          let priced_proof =
            { Priced_proof.proof =
                `One
                  (mk_dummy_proof
                     (Quickcheck.random_value
                        ~seed:(`Deterministic "test proof")
                        Transaction_snark.Statement.gen ) )
            ; fee =
                { fee = Currency.Fee.zero
                ; prover = Signature_lib.Public_key.Compressed.empty
                }
            }
          in
          let command =
            Mock_snark_pool.Resource_pool.Diff.Add_solved_work
              (fake_work, priced_proof)
          in
          don't_wait_for
          @@ Linear_pipe.iter (Mock_snark_pool.broadcasts network_pool)
               ~f:(fun _ ->
                 let pool = Mock_snark_pool.resource_pool network_pool in
                 ( match
                     Mock_snark_pool.Resource_pool.request_proof pool fake_work
                   with
                 | Some { proof; fee = _ } ->
                     assert (
                       [%equal: Ledger_proof.t One_or_two.t] proof
                         priced_proof.proof )
                 | None ->
                     failwith "There should have been a proof here" ) ;
                 Deferred.unit ) ;
          Mock_snark_pool.apply_and_broadcast network_pool
            (Envelope.Incoming.local command)
            (Mock_snark_pool.Broadcast_callback.Local (Fn.const ())) ;
          Deferred.unit )

    let%test_unit "when creating a network, the incoming diffs and locally \
                   generated diffs in reader pipes will automatically get \
                   process" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let work_count = 10 in
          let works =
            Quickcheck.random_sequence ~seed:(`Deterministic "works")
              Transaction_snark.Statement.gen
            |> Fn.flip Sequence.take work_count
            |> Sequence.map ~f:(fun x -> `One x)
            |> Sequence.to_list
          in
          let per_reader = work_count / 2 in
          let create_work work =
            Mock_snark_pool.Resource_pool.Diff.Add_solved_work
              ( work
              , Priced_proof.
                  { proof = One_or_two.map ~f:mk_dummy_proof work
                  ; fee =
                      { fee = Currency.Fee.zero
                      ; prover = Signature_lib.Public_key.Compressed.empty
                      }
                  } )
          in
          let verify_unsolved_work () =
            (*incomming diffs*)
            let%bind () = Async.Scheduler.yield_until_no_jobs_remain () in
            let frontier_broadcast_pipe_r, _ =
              Broadcast_pipe.create (Some (Mocks.Transition_frontier.create []))
            in
            let network_pool, remote_sink, local_sink =
              Mock_snark_pool.create ~logger ~config ~constraint_constants
                ~consensus_constants ~time_controller
                ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
                ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
            in
            List.map (List.take works per_reader) ~f:create_work
            |> List.map ~f:(fun work ->
                   ( Envelope.Incoming.local work
                   , Mina_net2.Validation_callback.create_without_expiration ()
                   ) )
            |> List.iter ~f:(fun diff ->
                   Mock_snark_pool.Remote_sink.push remote_sink diff
                   |> Deferred.don't_wait_for ) ;
            (* locally generated diffs *)
            List.map (List.drop works per_reader) ~f:create_work
            |> List.iter ~f:(fun diff ->
                   Mock_snark_pool.Local_sink.push local_sink (diff, Fn.const ())
                   |> Deferred.don't_wait_for ) ;
            don't_wait_for
            @@ Linear_pipe.iter (Mock_snark_pool.broadcasts network_pool)
                 ~f:(fun With_nonce.{ message = work_command; _ } ->
                   let work =
                     match work_command with
                     | Mock_snark_pool.Resource_pool.Diff.Add_solved_work
                         (work, _) ->
                         work
                     | Mock_snark_pool.Resource_pool.Diff.Empty ->
                         assert false
                   in
                   assert (
                     List.mem works work
                       ~equal:
                         [%equal: Transaction_snark.Statement.t One_or_two.t] ) ;
                   Deferred.unit ) ;
            Deferred.unit
          in
          verify_unsolved_work () )

    let%test_unit "rebroadcast behavior" =
      let tf = Mocks.Transition_frontier.create [] in
      let frontier_broadcast_pipe_r, _w = Broadcast_pipe.create (Some tf) in
      let stmt1, stmt2, stmt3, stmt4 =
        let gen_not_any l =
          Quickcheck.Generator.filter Mocks.Transaction_snark_work.Statement.gen
            ~f:(fun x ->
              List.for_all l ~f:(fun y ->
                  Mocks.Transaction_snark_work.Statement.compare x y <> 0 ) )
        in
        let open Quickcheck.Generator.Let_syntax in
        Quickcheck.random_value ~seed:(`Deterministic "")
          (let%bind a = gen_not_any [] in
           let%bind b = gen_not_any [ a ] in
           let%bind c = gen_not_any [ a; b ] in
           let%map d = gen_not_any [ a; b; c ] in
           (a, b, c, d) )
      in
      let fee1, fee2, fee3, fee4 =
        Quickcheck.random_value ~seed:(`Deterministic "")
          (Quickcheck.Generator.tuple4 Fee_with_prover.gen Fee_with_prover.gen
             Fee_with_prover.gen Fee_with_prover.gen )
      in
      let fake_sender =
        Envelope.Sender.Remote
          (Peer.create
             (Unix.Inet_addr.of_string "1.2.3.4")
             ~peer_id:(Peer.Id.unsafe_of_string "contents should be irrelevant")
             ~libp2p_port:8302 )
      in
      let compare_work (x : Mock_snark_pool.Resource_pool.Diff.t)
          (y : Mock_snark_pool.Resource_pool.Diff.t) =
        match (x, y) with
        | Add_solved_work (stmt1, _), Add_solved_work (stmt2, _) ->
            Transaction_snark_work.Statement.compare stmt1 stmt2
        | _ ->
            assert false
      in
      let check_work ~expected ~got =
        let sort = List.sort ~compare:compare_work in
        [%test_eq: Mock_snark_pool.Resource_pool.Diff.t list] (sort got)
          (sort expected)
      in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          let network_pool, _, _ =
            Mock_snark_pool.create ~logger:(Logger.null ()) ~config
              ~constraint_constants ~consensus_constants ~time_controller
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
              ~log_gossip_heard:false ~on_remote_push:(Fn.const Deferred.unit)
          in
          let resource_pool = Mock_snark_pool.resource_pool network_pool in
          let%bind () =
            Mocks.Transition_frontier.refer_statements tf
              [ stmt1; stmt2; stmt3; stmt4 ]
          in
          let%bind res1 =
            apply_diff ~sender:fake_sender resource_pool stmt1 fee1
          in
          let ok_exn = function
            | Ok e ->
                e
            | Error (`Other e) ->
                Or_error.ok_exn (Error e)
            | Error (`Locally_generated _) ->
                failwith "rejected because locally generated"
          in
          ignore
            ( ok_exn res1
              : [ `Accept | `Reject ]
                * Mock_snark_pool.Resource_pool.Diff.verified
                * Mock_snark_pool.Resource_pool.Diff.rejected ) ;
          let rebroadcastable1 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~has_timed_out:(Fn.const `Ok)
          in
          check_work ~got:rebroadcastable1 ~expected:[] ;
          let%bind res2 = apply_diff resource_pool stmt2 fee2 in
          let proof2 = One_or_two.map ~f:mk_dummy_proof stmt2 in
          ignore
            ( ok_exn res2
              : [ `Accept | `Reject ]
                * Mock_snark_pool.Resource_pool.Diff.verified
                * Mock_snark_pool.Resource_pool.Diff.rejected ) ;
          let rebroadcastable2 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~has_timed_out:(Fn.const `Ok)
          in
          check_work ~got:rebroadcastable2
            ~expected:
              [ Add_solved_work (stmt2, { proof = proof2; fee = fee2 }) ] ;
          let%bind res3 = apply_diff resource_pool stmt3 fee3 in
          let proof3 = One_or_two.map ~f:mk_dummy_proof stmt3 in
          ignore
            ( ok_exn res3
              : [ `Accept | `Reject ]
                * Mock_snark_pool.Resource_pool.Diff.verified
                * Mock_snark_pool.Resource_pool.Diff.rejected ) ;
          let rebroadcastable3 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~has_timed_out:(Fn.const `Ok)
          in
          check_work ~got:rebroadcastable3
            ~expected:
              [ Add_solved_work (stmt2, { proof = proof2; fee = fee2 })
              ; Add_solved_work (stmt3, { proof = proof3; fee = fee3 })
              ] ;
          (* Keep rebroadcasting even after the timeout, as long as the work
             hasn't appeared in a block yet.
          *)
          let rebroadcastable4 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~has_timed_out:(Fn.const `Timed_out)
          in
          check_work ~got:rebroadcastable4
            ~expected:
              [ Add_solved_work (stmt2, { proof = proof2; fee = fee2 })
              ; Add_solved_work (stmt3, { proof = proof3; fee = fee3 })
              ] ;
          let%bind res6 = apply_diff resource_pool stmt4 fee4 in
          let proof4 = One_or_two.map ~f:mk_dummy_proof stmt4 in
          ignore
            ( ok_exn res6
              : [ `Accept | `Reject ]
                * Mock_snark_pool.Resource_pool.Diff.verified
                * Mock_snark_pool.Resource_pool.Diff.rejected ) ;
          (* Mark best tip as not including stmt3. *)
          let%bind () =
            Mocks.Transition_frontier.remove_from_best_tip tf [ stmt3 ]
          in
          let rebroadcastable5 =
            Mock_snark_pool.For_tests.get_rebroadcastable resource_pool
              ~has_timed_out:(Fn.const `Ok)
          in
          check_work ~got:rebroadcastable5
            ~expected:
              [ Add_solved_work (stmt2, { proof = proof2; fee = fee2 })
              ; Add_solved_work (stmt4, { proof = proof4; fee = fee4 })
              ] ;
          Deferred.unit )
  end )
