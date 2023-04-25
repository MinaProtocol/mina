open Core_kernel
open Async_kernel
open Network_peer

(* Only show stdout for failed inline tests. *)
open Inline_test_quiet_logs

module Id = Unique_id.Int ()

type ('init, 'result) elt =
  { id : Id.t
  ; data : 'init
  ; weight : int
  ; res : (('result, Verifier.invalid) Result.t Or_error.t Ivar.t[@sexp.opaque])
  }
[@@deriving sexp]

type ('proof, 'result) state =
  | Waiting
  | Verifying of { out_for_verification : ('proof, 'result) elt list }
[@@deriving sexp]

module Q = Doubly_linked

type ('init, 'partially_validated, 'result) t =
  { mutable state : ('init, 'result) state
  ; how_to_add : [ `Insert | `Enqueue_back ]
  ; queue : ('init, 'result) elt Q.t
  ; compare_init : ('init -> 'init -> int) option
  ; logger : (Logger.t[@sexp.opaque])
  ; weight : 'init -> int
  ; max_weight_per_call : int option
  ; verifier :
      (   (* The batched verifier may make partial progress on its input so that we can
             save time when it is re-verified in a smaller batch in the case that a batch
             fails to verify.
          *)
          [ `Init of 'init | `Partially_validated of 'partially_validated ] list
       -> [ `Valid of 'result
          | Verifier.invalid
          | `Potentially_invalid of 'partially_validated * Error.t ]
          list
          Deferred.Or_error.t
      [@sexp.opaque] )
  }
[@@deriving sexp]

let create ?(how_to_add = `Enqueue_back) ?logger ?compare_init
    ?(weight = fun _ -> 1) ?max_weight_per_call verifier =
  { state = Waiting
  ; queue = Q.create ()
  ; how_to_add
  ; compare_init
  ; verifier
  ; weight
  ; max_weight_per_call
  ; logger = Option.value logger ~default:(Logger.create ())
  }

let call_verifier t (ps : 'proof list) = t.verifier ps

(* Worst case (if all the proofs are invalid): log n * (2^(log n) + 1)
   In the average case this should show better performance.
   We could implement the trusted/untrusted batches from the snark pool batching RFC #4882
   to further mitigate possible DoS/DDoS here
*)
let rec determine_outcome :
    type p r partial.
       (p, r) elt list
    -> [ `Valid of r
       | `Potentially_invalid of partial * Error.t
       | Verifier.invalid ]
       list
    -> (p, partial, r) t
    -> unit Deferred.Or_error.t =
 fun ps res v ->
  O1trace.thread "determining_batcher_outcome" (fun () ->
      (* First separate out all the known results. That information will definitely be included
         in the outcome.
      *)
      let logger = Logger.create () in
      let potentially_invalid =
        List.filter_map (List.zip_exn ps res) ~f:(fun (elt, r) ->
            match r with
            | `Valid r ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res (Ok (Ok r)) ;
                None
            | `Invalid_keys keys ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res (Ok (Error (`Invalid_keys keys))) ;
                None
            | `Invalid_signature keys ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res (Ok (Error (`Invalid_signature keys))) ;
                None
            | `Invalid_proof err ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res (Ok (Error (`Invalid_proof err))) ;
                None
            | `Missing_verification_key keys ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res (Ok (Error (`Missing_verification_key keys))) ;
                None
            | `Unexpected_verification_key keys ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res
                  (Ok (Error (`Unexpected_verification_key keys))) ;
                None
            | `Mismatched_authorization_kind keys ->
                if Ivar.is_full elt.res then
                  [%log error] "Ivar.fill bug is here!" ;
                Ivar.fill elt.res
                  (Ok (Error (`Mismatched_authorization_kind keys))) ;
                None
            | `Potentially_invalid (new_hint, err) ->
                Some (elt, new_hint, err) )
      in
      let open Deferred.Or_error.Let_syntax in
      match potentially_invalid with
      | [] ->
          (* All results are known *)
          return ()
      | [ ({ res; _ }, _, err) ] ->
          if Ivar.is_full res then [%log error] "Ivar.fill bug is here!" ;
          Ivar.fill res (Ok (Error (`Invalid_proof err))) ;
          (* If there is a potentially invalid proof in this batch of size 1, then
             that proof is itself invalid. *)
          return ()
      | _ ->
          let outcome xs =
            let%bind res_xs =
              call_verifier v
                (List.map xs ~f:(fun (_e, new_hint, _) ->
                     `Partially_validated new_hint ) )
            in
            determine_outcome (List.map xs ~f:(fun (e, _, _) -> e)) res_xs v
          in
          let length = List.length potentially_invalid in
          let left, right = List.split_n potentially_invalid (length / 2) in
          let%bind () = outcome left in
          outcome right )

let compare_elt ~compare t1 t2 =
  match compare t1.data t2.data with 0 -> Id.compare t1.id t2.id | x -> x

let order_proofs t =
  match t.compare_init with
  | None ->
      Fn.id
  | Some compare ->
      List.sort ~compare:(compare_elt ~compare)

(* When new proofs come in put them in the queue.
      If state = Waiting, verify those proofs immediately.
      Whenever the verifier returns, if the queue is nonempty, flush it into the verifier.
*)

let rec start_verifier : type proof partial r. (proof, partial, r) t -> unit =
 fun t ->
  O1trace.sync_thread "running_batcher_verifier_loop" (fun () ->
      if Q.is_empty t.queue then
        (* we looped in the else after verifier finished but no pending work. *)
        t.state <- Waiting
      else (
        [%log' debug t.logger] "Verifying proofs in batch of size $num_proofs"
          ~metadata:[ ("num_proofs", `Int (Q.length t.queue)) ] ;
        let out_for_verification =
          let proofs =
            match t.max_weight_per_call with
            | None ->
                let proofs = Q.to_list t.queue in
                Q.clear t.queue ; proofs
            | Some max_weight ->
                let rec take capacity acc =
                  match Q.first t.queue with
                  | None ->
                      acc
                  | Some ({ weight; _ } as proof) ->
                      if weight <= capacity then (
                        ignore (Q.remove_first t.queue : (proof, r) elt option) ;
                        take (capacity - weight) (proof :: acc) )
                      else acc
                in
                List.rev (take max_weight [])
          in
          order_proofs t proofs
        in
        [%log' debug t.logger] "Calling verifier with $num_proofs on $ids"
          ~metadata:
            [ ("num_proofs", `Int (List.length out_for_verification))
            ; ( "ids"
              , `List
                  (List.map
                     ~f:(fun { id; _ } -> `Int (Id.to_int_exn id))
                     out_for_verification ) )
            ] ;
        let res =
          match%bind
            call_verifier t
              (List.map out_for_verification ~f:(fun { data = p; _ } -> `Init p))
          with
          | Error e ->
              Deferred.return (Error e)
          | Ok res ->
              determine_outcome out_for_verification res t
        in
        t.state <- Verifying { out_for_verification } ;
        upon res (fun r ->
            ( match r with
            | Ok () ->
                ()
            | Error e ->
                List.iter out_for_verification ~f:(fun x ->
                    Ivar.fill_if_empty x.res (Error e) ) ) ;
            start_verifier t ) ) )

let verify (type p r partial) (t : (p, partial, r) t) (proof : p) :
    (r, Verifier.invalid) Result.t Deferred.Or_error.t =
  let elt =
    { id = Id.create ()
    ; data = proof
    ; weight = t.weight proof
    ; res = Ivar.create ()
    }
  in
  ignore
    ( match (t.how_to_add, t.compare_init) with
      | `Enqueue_back, _ | `Insert, None ->
          Q.insert_last t.queue elt
      | `Insert, Some compare -> (
          (* Find the first element that [proof] is less than *)
          let compare = compare_elt ~compare in
          match Q.find_elt t.queue ~f:(fun e -> compare elt e < 0) with
          | None ->
              (* [proof] is greater than all elts in the queue, and so goes in the back. *)
              Q.insert_last t.queue elt
          | Some succ ->
              Q.insert_before t.queue succ elt )
      : (p, r) elt Q.Elt.t ) ;
  (match t.state with Verifying _ -> () | Waiting -> start_verifier t) ;
  Ivar.read elt.res

type ('a, 'b, 'c) batcher = ('a, 'b, 'c) t [@@deriving sexp]

let compare_envelope (e1 : _ Envelope.Incoming.t) (e2 : _ Envelope.Incoming.t) =
  Envelope.Sender.compare e1.sender e2.sender

module Transaction_pool = struct
  open Mina_base

  type diff = User_command.Verifiable.t list Envelope.Incoming.t
  [@@deriving sexp]

  (* A partially verified transaction is either valid, or valid assuming that some list of
     (verification key, statement, proof) triples will verify. That is, the transaction has
     already been validated in all ways, except the proofs were in a batch that failed to
     verify.
  *)
  type partial_item =
    [ `Valid of User_command.Valid.t
    | `Valid_assuming of
      User_command.Verifiable.t
      * ( Pickles.Side_loaded.Verification_key.t
        * Zkapp_statement.t
        * Pickles.Side_loaded.Proof.t )
        list ]
  [@@deriving sexp]

  type partial = partial_item list [@@deriving sexp]

  type t = (diff, partial, User_command.Valid.t list) batcher [@@deriving sexp]

  type input = [ `Init of diff | `Partially_validated of partial ]

  let init_result (ds : input list) =
    (* We store a result for every diff in the input. *)
    Array.of_list_map ds ~f:(function
      | `Init d ->
          (* Initially, the status of all the transactions in a never-before-seen
             diff are unknown. *)
          `In_progress (Array.of_list_map d.data ~f:(fun _ -> `Unknown))
      | `Partially_validated d ->
          (* We've seen this diff before, so we have some information about its
             transactions. *)
          `In_progress
            (Array.of_list_map d ~f:(function
              | `Valid c ->
                  `Valid c
              | `Valid_assuming x ->
                  `Valid_assuming x ) ) )

  let list_of_array_map a ~f = List.init (Array.length a) ~f:(fun i -> f a.(i))

  let all_valid a =
    Option.all
      (Array.to_list
         (Array.map a ~f:(function `Valid c -> Some c | _ -> None)) )

  let create verifier : t =
    let logger = Logger.create () in
    create ~compare_init:compare_envelope ~logger (fun (ds : input list) ->
        O1trace.thread "dispatching_transaction_pool_batcher_verification"
          (fun () ->
            [%log debug]
              "Dispatching $num_proofs transaction pool proofs to verifier"
              ~metadata:[ ("num_proofs", `Int (List.length ds)) ] ;
            let open Deferred.Or_error.Let_syntax in
            let result = init_result ds in
            (* Extract all the transactions that have not yet been fully validated and hold on to their
               position (diff index, position in diff). *)
            let unknowns =
              List.concat_mapi ds ~f:(fun i x ->
                  match x with
                  | `Init diff ->
                      List.mapi diff.data ~f:(fun j c -> ((i, j), c))
                  | `Partially_validated partial ->
                      List.filter_mapi partial ~f:(fun j c ->
                          match c with
                          | `Valid _ ->
                              None
                          | `Valid_assuming (v, _) ->
                              (* TODO: This rechecks the signatures on zkApp transactions... oh well for now *)
                              Some ((i, j), v) ) )
            in
            let%map res =
              (* Verify the unknowns *)
              Verifier.verify_commands verifier
                (List.map unknowns ~f:(fun (_, txn) ->
                     { With_status.data = txn; status = Applied } ) )
            in
            (* We now iterate over the results of the unknown transactions and appropriately modify
               the verification result of the diff that it belongs to. *)
            List.iter2_exn unknowns res ~f:(fun ((i, j), v) r ->
                match r with
                | `Invalid_keys keys ->
                    (* A diff is invalid is any of the transactions it contains are invalid.
                       Invalidate the whole diff that this transaction comes from. *)
                    result.(i) <- `Invalid_keys keys
                | `Invalid_signature keys ->
                    (* Invalidate the whole diff *)
                    result.(i) <- `Invalid_signature keys
                | `Missing_verification_key keys ->
                    (* Invalidate the whole diff *)
                    result.(i) <- `Missing_verification_key keys
                | `Unexpected_verification_key keys ->
                    (* Invalidate the whole diff *)
                    result.(i) <- `Unexpected_verification_key keys
                | `Mismatched_authorization_kind keys ->
                    (* Invalidate the whole diff *)
                    result.(i) <- `Mismatched_authorization_kind keys
                | `Invalid_proof err ->
                    (* Invalidate the whole diff *)
                    result.(i) <- `Invalid_proof err
                | `Valid_assuming xs -> (
                    match result.(i) with
                    | `Invalid_keys _
                    | `Invalid_signature _
                    | `Invalid_proof _
                    | `Missing_verification_key _
                    | `Unexpected_verification_key _
                    | `Mismatched_authorization_kind _ ->
                        (* If this diff has already been declared invalid, knowing that one of its
                           transactions is partially valid is not useful. *)
                        ()
                    | `In_progress a ->
                        (* The diff may still be valid. *)
                        a.(j) <- `Valid_assuming (v, xs) )
                | `Valid c -> (
                    (* Similar to the above. *)
                    match result.(i) with
                    | `Invalid_keys _
                    | `Invalid_signature _
                    | `Invalid_proof _
                    | `Missing_verification_key _
                    | `Unexpected_verification_key _
                    | `Mismatched_authorization_kind _ ->
                        ()
                    | `In_progress a ->
                        a.(j) <- `Valid c ) ) ;
            list_of_array_map result ~f:(function
              | `Invalid_keys keys ->
                  `Invalid_keys keys
              | `Invalid_signature keys ->
                  `Invalid_signature keys
              | `Invalid_proof err ->
                  `Invalid_proof err
              | `Missing_verification_key keys ->
                  `Missing_verification_key keys
              | `Unexpected_verification_key keys ->
                  `Unexpected_verification_key keys
              | `Mismatched_authorization_kind keys ->
                  `Mismatched_authorization_kind keys
              | `In_progress a -> (
                  (* If the diff is all valid, we're done. If not, we return a partial
                       result. *)
                  match all_valid a with
                  | Some res ->
                      `Valid res
                  | None ->
                      `Potentially_invalid
                        ( list_of_array_map a ~f:(function
                            | `Unknown ->
                                assert false
                            | `Valid c ->
                                `Valid c
                            | `Valid_assuming (v, xs) ->
                                `Valid_assuming (v, xs) )
                        , Error.of_string "In progress" ) ) ) ) )

  let verify (t : t) = verify t
end

module Snark_pool = struct
  type proof_envelope =
    (Ledger_proof.t One_or_two.t * Mina_base.Sok_message.t) Envelope.Incoming.t
  [@@deriving sexp]

  (* We don't use partial verification here. *)
  type partial = proof_envelope [@@deriving sexp]

  type t = (proof_envelope, partial, unit) batcher [@@deriving sexp]

  let verify (t : t) (p : proof_envelope) : bool Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    match%map verify t p with Ok () -> true | Error _ -> false

  let create verifier : t =
    let logger = Logger.create () in
    create
    (* TODO: Make this a proper config detail once we have data on what a
           good default would be.
    *)
      ~max_weight_per_call:
        (Option.value_map ~default:1000 ~f:Int.of_string
           (Sys.getenv_opt "MAX_VERIFIER_BATCH_SIZE") )
      ~compare_init:compare_envelope ~logger
      (fun ps0 ->
        [%log debug] "Dispatching $num_proofs snark pool proofs to verifier"
          ~metadata:[ ("num_proofs", `Int (List.length ps0)) ] ;
        let ps =
          List.concat_map ps0 ~f:(function
              | `Partially_validated env | `Init env ->
              let ps, message = env.data in
              One_or_two.map ps ~f:(fun p -> (p, message)) |> One_or_two.to_list )
        in
        let open Deferred.Or_error.Let_syntax in
        let%map result = Verifier.verify_transaction_snarks verifier ps in
        match result with
        | Ok () ->
            List.map ps0 ~f:(fun _ -> `Valid ())
        | Error err ->
            List.map ps0 ~f:(function `Partially_validated env | `Init env ->
                `Potentially_invalid (env, err) ) )

  module Work_key = struct
    module T = struct
      type t =
        (Transaction_snark.Statement.t One_or_two.t * Mina_base.Sok_message.t)
        Envelope.Incoming.t
      [@@deriving sexp, compare]
    end

    let of_proof_envelope t =
      Envelope.Incoming.map t ~f:(fun (ps, message) ->
          (One_or_two.map ~f:Ledger_proof.statement ps, message) )

    include T
    include Comparable.Make (T)
  end

  let verify' (t : t) ps =
    let open Deferred.Or_error.Let_syntax in
    let%map invalid =
      Deferred.Or_error.List.filter_map ps ~f:(fun p ->
          match%map verify t p with true -> None | false -> Some p )
    in
    `Invalid
      (Work_key.Set.of_list (List.map invalid ~f:Work_key.of_proof_envelope))

  let%test_module "With valid and invalid proofs" =
    ( module struct
      open Mina_base

      let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

      let proof_level = precomputed_values.proof_level

      let constraint_constants = precomputed_values.constraint_constants

      let logger = Logger.null ()

      let verifier =
        Async.Thread_safe.block_on_async_exn (fun () ->
            Verifier.create ~logger ~proof_level ~constraint_constants
              ~conf_dir:None
              ~pids:(Child_processes.Termination.create_pid_table ())
              () )

      let gen_proofs =
        let open Quickcheck.Generator.Let_syntax in
        let data_gen =
          let%bind statements =
            One_or_two.gen Transaction_snark.Statement.gen
          in
          let%map { fee; prover } = Fee_with_prover.gen in
          let message = Mina_base.Sok_message.create ~fee ~prover in
          ( One_or_two.map statements ~f:Ledger_proof.For_tests.mk_dummy_proof
          , message )
        in
        Envelope.Incoming.gen data_gen

      let gen_invalid_proofs =
        let open Quickcheck.Generator.Let_syntax in
        let data_gen =
          let%bind statements =
            One_or_two.gen Transaction_snark.Statement.gen
          in
          let%bind { fee; prover } = Fee_with_prover.gen in
          let%map invalid_prover =
            Quickcheck.Generator.filter Signature_lib.Public_key.Compressed.gen
              ~f:(Signature_lib.Public_key.Compressed.( <> ) prover)
          in
          let sok_digest =
            Mina_base.Sok_message.(digest (create ~fee ~prover:invalid_prover))
          in
          let message = Mina_base.Sok_message.create ~fee ~prover in
          ( One_or_two.map statements ~f:(fun statement ->
                Ledger_proof.create ~statement ~sok_digest
                  ~proof:Proof.transaction_dummy )
          , message )
        in
        Envelope.Incoming.gen data_gen

      let run_test proof_lists =
        let batcher = create verifier in
        Deferred.List.iter proof_lists ~f:(fun (invalid_proofs, proof_list) ->
            let%map r = verify' batcher proof_list in
            let (`Invalid ps) = Or_error.ok_exn r in
            assert (Work_key.Set.equal ps invalid_proofs) )

      let gen ~(valid_count : [ `Any | `Count of int ])
          ~(invalid_count : [ `Any | `Count of int ]) =
        let open Quickcheck.Generator.Let_syntax in
        let gen_with_count count gen =
          match count with
          | `Any ->
              Quickcheck.Generator.list_non_empty gen
          | `Count c ->
              Quickcheck.Generator.list_with_length c gen
        in
        let invalid_gen = gen_with_count invalid_count gen_invalid_proofs in
        let valid_gen = gen_with_count valid_count gen_proofs in
        let%map lst =
          Quickcheck.Generator.(list (both valid_gen invalid_gen))
        in
        List.map lst ~f:(fun (valid, invalid) ->
            ( Work_key.(Set.of_list (List.map ~f:of_proof_envelope invalid))
            , List.permute valid @ invalid ) )

      let%test_unit "all valid proofs" =
        Quickcheck.test ~trials:10
          (gen ~valid_count:`Any ~invalid_count:(`Count 0))
          ~f:(fun proof_lists ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                run_test proof_lists ) )

      let%test_unit "some invalid proofs" =
        Quickcheck.test ~trials:10
          (gen ~valid_count:`Any ~invalid_count:`Any)
          ~f:(fun proof_lists ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                run_test proof_lists ) )

      let%test_unit "all invalid proofs" =
        Quickcheck.test ~trials:10
          (gen ~valid_count:(`Count 0) ~invalid_count:`Any)
          ~f:(fun proof_lists ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                run_test proof_lists ) )
    end )
end
