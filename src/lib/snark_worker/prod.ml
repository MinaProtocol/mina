open Async
open Core
open Mina_base
open Mina_transaction
module Work = Snark_work_lib

module Cache = struct
  module T = Hash_heap.Make (Transaction_snark.Statement)

  type t = (Time.t * Transaction_snark.t) T.t

  let max_size = 100

  let create () : t = T.create (fun (t1, _) (t2, _) -> Time.compare t1 t2)

  let add t ~statement ~proof =
    T.push_exn t ~key:statement ~data:(Time.now (), proof) ;
    if Int.( > ) (T.length t) max_size then ignore (T.pop_exn t)

  let find (t : t) statement = Option.map ~f:snd (T.find t statement)
end

module Impl : Intf.Worker = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type module_with_proof_level = Check | No_check | Full of (module S)

    type t =
      { m_with_proof_level : module_with_proof_level
      ; cache : Cache.t
      ; proof_cache_db : Proof_cache_tag.cache_db
      ; logger : Logger.t
      }

    let create ~constraint_constants ~proof_level () =
      let proof_cache_db = Proof_cache_tag.create_identity_db () in
      let m_with_proof_level =
        match proof_level with
        | Genesis_constants.Proof_level.Full ->
            Full
              ( module Transaction_snark.Make (struct
                let constraint_constants = constraint_constants

                let proof_level = proof_level
              end) )
        | Check ->
            Check
        | No_check ->
            No_check
      in
      Deferred.return
        { m_with_proof_level
        ; cache = Cache.create ()
        ; proof_cache_db
        ; logger = Logger.create ()
        }

    let worker_wait_time = 5.
  end

  let log_zkapp_cmd_base_snark ~logger ~statement ~spec f () =
    match%map.Deferred
      Deferred.Or_error.try_with ~here:[%here] (fun () -> f ~statement ~spec)
    with
    | Ok p ->
        Ok p
    | Error e ->
        [%log fatal]
          "Transaction snark failed for input $spec $statement. All inputs: \
           $inputs. Error:  $error"
          ~metadata:
            [ ( "spec"
              , Transaction_snark.Zkapp_command_segment.Basic.to_yojson spec )
            ; ( "statement"
              , Transaction_snark.Statement.With_sok.to_yojson statement )
            ; ("error", `String (Error.to_string_hum e))
            ] ;
        Error e

  let log_zkapp_cmd_merge_snark ~m:(module M : Worker_state.S) ~logger
      ~sok_digest prev curr () =
    match%map.Deferred M.merge ~sok_digest prev curr with
    | Ok p ->
        Ok p
    | Error e ->
        [%log fatal]
          "Merge snark failed for $stmt1 $stmt2. All inputs: $inputs. Error:  \
           $error"
          ~metadata:
            [ ( "stmt1"
              , Transaction_snark.Statement.to_yojson
                  (Ledger_proof.statement prev) )
            ; ( "stmt2"
              , Transaction_snark.Statement.to_yojson
                  (Ledger_proof.statement curr) )
            ; ("error", `String (Error.to_string_hum e))
            ] ;
        Error e

  let cache_and_time ~logger ~cache ~statement
      ~(partitioned_spec : Work.Spec.Partitioned.Stable.Latest.t) k =
    match (Cache.find cache) statement with
    | Some proof ->
        Deferred.Or_error.return (proof, Time.Span.zero)
    | None -> (
        let start = Time.now () in
        match%map.Async.Deferred
          Monitor.try_with_join_or_error ~here:[%here] k
        with
        | Error e ->
            [%log error] "SNARK worker failed: $error"
              ~metadata:
                [ ("error", Error_json.error_to_yojson e)
                ; ( "spec"
                    (* the [@sexp.opaque] in Work.Single.Spec.t means we can't derive yojson,
                       so we use the less-desirable sexp here
                    *)
                  , `String
                      ( Work.Spec.Partitioned.Stable.Latest.sexp_of_t
                          partitioned_spec
                      |> Sexp.to_string ) )
                ] ;
            Error e
        | Ok res ->
            Cache.add cache ~statement ~proof:res ;
            let elapsed = Time.abs_diff (Time.now ()) start in
            Ok (res, elapsed) )

  let perform_single_raw ~(m : (module Worker_state.S)) ~logger ~proof_cache_db
      ~(single_spec : Work.Spec.Single.Stable.Latest.t) ~sok_digest () =
    let open Deferred.Or_error.Let_syntax in
    let (module M) = m in
    match single_spec with
    | Transition (input, (witness : Transaction_witness.Stable.Latest.t)) -> (
        match witness.transaction with
        | Command (Zkapp_command zkapp_command) -> (
            let
            (* WARN: this path is still required for uptime snark workers *)
            open
              Work_partitioner.Snark_worker_shared in
            let zkapp_command_cached =
              Zkapp_command.write_all_proofs_to_disk ~proof_cache_db
                zkapp_command
            in
            let%bind witnesses_specs_stmts =
              Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works
                ~m ~input ~witness ~zkapp_command:zkapp_command_cached
            in
            match witnesses_specs_stmts with
            | [] ->
                Deferred.Or_error.error_string "no witnesses generated"
            | (witness, spec, stmt) :: rest as all_inputs ->
                let%bind (p1 : Ledger_proof.t) =
                  log_zkapp_cmd_base_snark ~logger
                    ~statement:{ stmt with sok_digest } ~spec
                    (M.of_zkapp_command_segment_exn ~witness)
                    ()
                in

                let%bind (p : Ledger_proof.t) =
                  Deferred.List.fold ~init:(Ok p1) rest
                    ~f:(fun acc (witness, spec, stmt) ->
                      let%bind (prev : Ledger_proof.t) = Deferred.return acc in
                      let%bind (curr : Ledger_proof.t) =
                        log_zkapp_cmd_base_snark ~logger
                          ~statement:{ stmt with sok_digest } ~spec
                          (M.of_zkapp_command_segment_exn ~witness)
                          ()
                      in
                      log_zkapp_cmd_merge_snark ~m ~logger ~sok_digest prev curr
                        () )
                in
                if
                  Transaction_snark.Statement.equal (Ledger_proof.statement p)
                    input
                then Deferred.return (Ok p)
                else (
                  [%log fatal]
                    "Zkapp_command transaction final statement mismatch \
                     Expected $expected Got $got. All inputs: $inputs"
                    ~metadata:
                      [ ( "got"
                        , Transaction_snark.Statement.to_yojson
                            (Ledger_proof.statement p) )
                      ; ("expected", Transaction_snark.Statement.to_yojson input)
                      ; ( "inputs"
                        , Zkapp_command_inputs.(
                            read_all_proofs_from_disk all_inputs
                            |> Stable.Latest.to_yojson) )
                      ] ;
                  Deferred.return
                    (Or_error.error_string
                       "Zkapp_command transaction final statement mismatch" ) )
            )
        | _ ->
            let%bind t =
              Deferred.return
              @@
              (* Validate the received transaction *)
              match witness.transaction with
              | Command (Signed_command cmd) -> (
                  match Signed_command.check cmd with
                  | Some cmd ->
                      ( Ok (Command (Signed_command cmd))
                        : Transaction.Valid.t Or_error.t )
                  | None ->
                      Or_error.errorf "Command has an invalid signature" )
              | Command (Zkapp_command _) ->
                  assert false
              | Fee_transfer ft ->
                  Ok (Fee_transfer ft)
              | Coinbase cb ->
                  Ok (Coinbase cb)
            in
            Deferred.Or_error.try_with ~here:[%here] (fun () ->
                M.of_non_zkapp_command_transaction
                  ~statement:{ input with sok_digest }
                  { Transaction_protocol_state.Poly.transaction = t
                  ; block_data = witness.protocol_state_body
                  ; global_slot = witness.block_global_slot
                  }
                  ~init_stack:witness.init_stack
                  (unstage
                     (Mina_ledger.Sparse_ledger.handler
                        witness.first_pass_ledger ) ) ) )
    | Merge (_, proof1, proof2) ->
        M.merge ~sok_digest proof1 proof2

  let perform_single_non_zkapp_cached ~(logger : Logger.t) ~(cache : Cache.t)
      ~proof_cache_db ~(m : (module Worker_state.S)) ~sok_digest
      ~partitioned_spec ~(single_spec : Work.Spec.Single.Stable.Latest.t) () =
    let statement = Work.Spec.Single.Poly.statement single_spec in
    cache_and_time ~logger ~cache ~statement ~partitioned_spec
      (perform_single_raw ~m ~logger ~proof_cache_db ~single_spec ~sok_digest)

  let perform
      ~state:
        ({ m_with_proof_level; cache; proof_cache_db; logger } : Worker_state.t)
      ~spec:(partitioned_spec : Work.Spec.Partitioned.Stable.Latest.t)
      ~(sok_digest : Mina_base.Sok_message.Digest.t) :
      Work.Result.Partitioned.Stable.Latest.t Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    match m_with_proof_level with
    | Worker_state.Full ((module M) as m) -> (
        match partitioned_spec with
        | Work.Spec.Partitioned.Poly.Single
            { job = { spec = single_spec; _ } as job; data = () } ->
            let%map proof, elapsed =
              perform_single_non_zkapp_cached ~logger ~cache ~m ~sok_digest
                ~proof_cache_db ~single_spec ~partitioned_spec ()
            in

            Work.Spec.Partitioned.Poly.Single
              { job; data = { Proof_carrying_data.data = elapsed; proof } }
        | Work.Spec.Partitioned.Poly.Sub_zkapp_command
            { job =
                { spec =
                    Work.Spec.Sub_zkapp.Poly.Segment
                      { statement; witness; spec = segment_spec; _ } as
                    sub_zkapp_spec
                ; _
                } as job
            ; data = ()
            } ->
            let witness =
              Transaction_witness.Zkapp_command_segment_witness
              .write_all_proofs_to_disk ~proof_cache_db witness
            in

            let statement_without_sok =
              Work.Spec.Sub_zkapp.Poly.statement sub_zkapp_spec
            in

            let%map proof, elapsed =
              log_zkapp_cmd_base_snark ~logger ~statement ~spec:segment_spec
                (M.of_zkapp_command_segment_exn ~witness)
              |> cache_and_time ~logger ~cache ~statement:statement_without_sok
                   ~partitioned_spec
            in

            Work.Spec.Partitioned.Poly.Sub_zkapp_command
              { job; data = { Proof_carrying_data.data = elapsed; proof } }
        | Work.Spec.Partitioned.Poly.Sub_zkapp_command
            { job =
                { spec =
                    Work.Spec.Sub_zkapp.Poly.Merge { proof1; proof2 } as spec
                ; _
                } as job
            ; data = ()
            } ->
            let statement_without_sok =
              Work.Spec.Sub_zkapp.Poly.statement spec
            in

            let%map proof, elapsed =
              log_zkapp_cmd_merge_snark ~m ~logger ~sok_digest proof1 proof2
              |> cache_and_time ~logger ~cache ~statement:statement_without_sok
                   ~partitioned_spec
            in
            Work.Spec.Partitioned.Poly.Sub_zkapp_command
              { job; data = { Proof_carrying_data.data = elapsed; proof } } )
    | Worker_state.Check | Worker_state.No_check ->
        let elapsed = Time.Span.zero in
        let result =
          Work.Spec.Partitioned.Poly.map_with_statement
            ~f:(fun statement () ->
              Proof_carrying_data.
                { proof =
                    (* NOTE: use a dummy proof *)
                    Transaction_snark.create
                      ~statement:{ statement with sok_digest }
                      ~proof:(Lazy.force Proof.transaction_dummy)
                ; data = elapsed
                } )
            partitioned_spec
        in
        Deferred.Or_error.return result
end
