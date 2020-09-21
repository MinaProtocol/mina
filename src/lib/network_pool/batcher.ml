open Core_kernel
open Async_kernel
open Network_peer
open Pickles_types

module Id = Unique_id.Int ()

module Outcome = struct
  (* The final result of a batch verification. For each proof, a determination of
     whether or not it is valid.

     We allow valid proofs to carry data of type 'result, rather than just being
     propositional. This is to support, e.g., User_command.t's getting
     verified into a result of type User_command.Valid.t.
  *)
  type ('proof, 'result) t = [`Valid of 'result | `Invalid of 'proof] Id.Map.t
  [@@deriving sexp]

  let invalid invalid =
    Id.Map.of_alist_exn (List.map invalid ~f:(fun (id, x) -> (id, `Invalid x)))

  let to_invalid (t : _ t) =
    Map.fold t ~init:[] ~f:(fun ~key:_ ~data acc ->
        match data with `Valid _ -> acc | `Invalid x -> x :: acc )

  let of_alist_exn : _ -> _ t = Id.Map.of_alist_exn

  let empty : _ t = Id.Map.empty

  (* Merge the outcomes for two batches. Used to recombine results of
     recursive splitting *)
  let append (type p r) (t1 : (p, r) t) (t2 : (p, r) t) : (p, r) t =
    Id.Map.merge t1 t2 ~f:(fun ~key:_ d ->
        match d with
        | `Left x | `Right x ->
            Some x
        | `Both (x, y) -> (
          (* This should never happen. Still, we handle it
          in case the truly unthinkable occurs *)
          match (x, y) with
          | `Valid _, `Valid _ ->
              Some x
          | `Invalid _, `Invalid _ ->
              Some x
          | `Valid _, `Invalid _ | `Invalid _, `Valid _ ->
              assert false ) )
end

type ('proof, 'result) state =
  | Waiting
  | Verifying of
      { out_for_verification: (Id.t * 'proof) list
      ; next_finished:
          ('proof, 'result) Outcome.t Or_error.t Ivar.t sexp_opaque }
[@@deriving sexp]

type ('proof, 'partially_validated, 'result) t =
  { mutable state: ('proof, 'result) state
  ; queue: (Id.t * 'proof) Queue.t
  ; compare_proof: ('proof -> 'proof -> int) option
  ; verifier:
      (* The batched verifier may make partial progress on its input so that we can
         save time when it is re-verified in a smaller batch in the case that a batch
         fails to verify. *)
      (   [`Proof of 'proof | `Partially_validated of 'partially_validated] list
       -> [ `Valid of 'result
          | `Invalid
          | `Potentially_invalid of 'partially_validated ]
          list
          Deferred.Or_error.t)
      sexp_opaque }
[@@deriving sexp]

let create ?compare_proof verifier =
  {state= Waiting; queue= Queue.create (); compare_proof; verifier}

let call_verifier t (ps : 'proof list) = t.verifier ps

(*Worst case (if all the proofs are invalid): log n * (2^(log n) + 1)
  In the average case this should show better performance.
  We need to implement the trusted/untrusted batches from the snark pool batching RFC #4882 to avoid possible DoS/DDoS here*)
let rec determine_outcome : type p r partial.
       (Id.t * p) list
    -> [`Valid of r | `Invalid | `Potentially_invalid of partial] list
    -> (p, partial, r) t
    -> (p, r) Outcome.t Deferred.Or_error.t =
 fun ps res v ->
  (* First separate out all the known results. That information will definitely be included
    in the outcome. *)
  let known, potentially_invalid =
    List.partition_map (List.zip_exn ps res) ~f:(fun ((id, p), r) ->
        match r with
        | `Valid r ->
            `Fst (id, `Valid r)
        | `Invalid ->
            `Fst (id, `Invalid p)
        | `Potentially_invalid new_hint ->
            `Snd (id, p, new_hint) )
  in
  let open Deferred.Or_error.Let_syntax in
  match potentially_invalid with
  | [] ->
      (* All results are known *)
      return (Outcome.of_alist_exn known)
  | [(id, p, _)] ->
      (* If there is a potentially invalid proof in this batch of size 1, then
         that proof is itself invalid. *)
      return Outcome.(append (invalid [(id, p)]) (of_alist_exn known))
  | _ ->
      let outcome xs =
        let%bind res_xs =
          call_verifier v
            (List.map xs ~f:(fun (_id, _p, new_hint) ->
                 `Partially_validated new_hint ))
        in
        determine_outcome
          (List.map xs ~f:(fun (id, p, _hint) -> (id, p)))
          res_xs v
      in
      let length = List.length potentially_invalid in
      let left, right = List.split_n potentially_invalid (length / 2) in
      let%bind outcome_l = outcome left in
      let%map outcome_r = outcome right in
      List.fold known
        ~f:(fun acc (id, x) -> Map.add_exn acc ~key:id ~data:x)
        ~init:(Outcome.append outcome_l outcome_r)

let order_proofs t =
  match t.compare_proof with
  | None ->
      Fn.id
  | Some compare ->
      let compare (id1, p1) (id2, p2) =
        match compare p1 p2 with 0 -> Id.compare id1 id2 | x -> x
      in
      List.sort ~compare

(* When new proofs come in put them in the queue.
      If state = Waiting, verify those proofs immediately.
      Whenever the verifier returns, if the queue is nonempty, flush it into the verifier.
  *)

let rec start_verifier : type proof partial r.
    (proof, partial, r) t -> (proof, r) Outcome.t Or_error.t Ivar.t -> unit =
 fun t finished ->
  if Queue.is_empty t.queue then (
    (* we looped in the else after verifier finished but no pending work. *)
    t.state <- Waiting ;
    Ivar.fill finished (Ok Outcome.empty) )
  else
    let out_for_verification = order_proofs t (Queue.to_list t.queue) in
    let next_finished = Ivar.create () in
    t.state <- Verifying {next_finished; out_for_verification} ;
    Queue.clear t.queue ;
    let res =
      call_verifier t
        (List.map out_for_verification ~f:(fun (_id, p) -> `Proof p))
    in
    upon res (fun verification_res ->
        let outcome =
          match verification_res with
          | Error e ->
              Deferred.return (Error e)
          | Ok res ->
              determine_outcome out_for_verification res t
        in
        upon outcome (fun y -> Ivar.fill finished y) ) ;
    start_verifier t next_finished

let verify' (type p r partial n) (t : (p, partial, r) t)
    (proofs : (p, n) Vector.t) :
    (Id.t, n) Vector.t * (p, r) Outcome.t Deferred.Or_error.t =
  let proofs_with_ids = Vector.map proofs ~f:(fun p -> (Id.create (), p)) in
  Queue.enqueue_all t.queue (Vector.to_list proofs_with_ids) ;
  ( Vector.map proofs_with_ids ~f:fst
  , match t.state with
    | Verifying {next_finished; _} ->
        Ivar.read next_finished
    | Waiting ->
        let finished = Ivar.create () in
        start_verifier t finished ; Ivar.read finished )

let verify (type p r partial) (t : (p, partial, r) t) (proof : p) :
    (r, unit) Result.t Deferred.Or_error.t =
  let [id], d = verify' t [proof] in
  Deferred.Or_error.map d ~f:(fun outcome ->
      match Map.find_exn outcome id with
      | `Valid x ->
          Ok x
      | `Invalid _ ->
          Error () )

type ('a, 'b, 'c) batcher = ('a, 'b, 'c) t [@@deriving sexp]

let compare_envelope (e1 : _ Envelope.Incoming.t) (e2 : _ Envelope.Incoming.t)
    =
  Envelope.Sender.compare e1.sender e2.sender

module Transaction_pool = struct
  open Coda_base

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
        * Snapp_statement.t
        * Pickles.Side_loaded.Proof.t )
        list ]
  [@@deriving sexp]

  type partial = partial_item list [@@deriving sexp]

  type t = (diff, partial, User_command.Valid.t list) batcher [@@deriving sexp]

  type input = [`Proof of diff | `Partially_validated of partial]

  let init_result (ds : input list) =
    (* We store a result for every diff in the input. *)
    Array.of_list_map ds ~f:(function
      | `Proof d ->
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
                  `Valid_assuming x )) )

  let list_of_array_map a ~f = List.init (Array.length a) ~f:(fun i -> f a.(i))

  let all_valid a =
    Option.all
      (Array.to_list
         (Array.map a ~f:(function `Valid c -> Some c | _ -> None)))

  let create verifier : t =
    create ~compare_proof:compare_envelope (fun (ds : input list) ->
        let open Deferred.Or_error.Let_syntax in
        let result = init_result ds in
        (* Extract all the transactions that have not yet been fully validated and hold on to their
           position (diff index, position in diff). *)
        let unknowns =
          List.concat_mapi ds ~f:(fun i x ->
              match x with
              | `Proof diff ->
                  List.mapi diff.data ~f:(fun j c -> ((i, j), c))
              | `Partially_validated partial ->
                  List.filter_mapi partial ~f:(fun j c ->
                      match c with
                      | `Valid _ ->
                          None
                      | `Valid_assuming (v, _) ->
                          (* TODO: This rechecks the signatures on snapp transactions... oh well for now *)
                          Some ((i, j), v) ) )
        in
        let%map res =
          (* Verify the unknowns *)
          Verifier.verify_commands verifier (List.map unknowns ~f:snd)
        in
        (* We now iterate over the results of the unknown transactions and appropriately modify
           the verification result of the diff that it belongs to. *)
        List.iter2_exn unknowns res ~f:(fun ((i, j), v) r ->
            match r with
            | `Invalid ->
                (* A diff is invalid is any of the transactions it contains are invalid.
              Invalidate the whole diff that this transaction comes from. *)
                result.(i) <- `Invalid
            | `Valid_assuming xs -> (
              match result.(i) with
              | `Invalid ->
                  (* If this diff has already been declared invalid, knowing that one of its
                   transactions is partially valid is not useful. *)
                  ()
              | `In_progress a ->
                  (* The diff may still be valid. *)
                  a.(j) <- `Valid_assuming (v, xs) )
            | `Valid c -> (
              (* Similar to the above. *)
              match result.(i) with
              | `Invalid ->
                  ()
              | `In_progress a ->
                  a.(j) <- `Valid c ) ) ;
        list_of_array_map result ~f:(function
          | `Invalid ->
              `Invalid
          | `In_progress a -> (
            (* If the diff is all valid, we're done. If not, we return a partial
                 result. *)
            match all_valid a with
            | Some res ->
                `Valid res
            | None ->
                `Potentially_invalid
                  (list_of_array_map a ~f:(function
                    | `Unknown ->
                        assert false
                    | `Valid c ->
                        `Valid c
                    | `Valid_assuming (v, xs) ->
                        `Valid_assuming (v, xs) )) ) ) )

  let verify (t : t) = verify t
end

module Snark_pool = struct
  type proof_envelope =
    (Ledger_proof.t One_or_two.t * Coda_base.Sok_message.t) Envelope.Incoming.t
  [@@deriving sexp]

  (* We don't use partial verification here. *)
  type partial = proof_envelope [@@deriving sexp]

  type t = (proof_envelope, partial, unit) batcher [@@deriving sexp]

  let verify (t : t) (p : proof_envelope) : bool Deferred.Or_error.t =
    let open Deferred.Or_error.Let_syntax in
    match%map verify t p with Ok () -> true | Error () -> false

  let create verifier : t =
    create ~compare_proof:compare_envelope (fun ps0 ->
        let ps =
          List.concat_map ps0 ~f:(function
              | `Partially_validated env | `Proof env ->
              let ps, message = env.data in
              One_or_two.map ps ~f:(fun p -> (p, message))
              |> One_or_two.to_list )
        in
        let open Deferred.Or_error.Let_syntax in
        match%map Verifier.verify_transaction_snarks verifier ps with
        | true ->
            List.map ps0 ~f:(fun _ -> `Valid ())
        | false ->
            List.map ps0 ~f:(function
                | `Partially_validated env | `Proof env ->
                `Potentially_invalid env ) )

  module Work_key = struct
    module T = struct
      type t =
        (Transaction_snark.Statement.t One_or_two.t * Coda_base.Sok_message.t)
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
    let (T ps) = Vector.of_list ps in
    let%map outcome = verify' t ps |> snd in
    let invalid = Outcome.to_invalid outcome in
    `Invalid
      (Work_key.Set.of_list (List.map invalid ~f:Work_key.of_proof_envelope))

  let%test_module "With valid and invalid proofs" =
    ( module struct
      open Coda_base

      let proof_level = Genesis_constants.Proof_level.for_unit_tests

      let logger = Logger.null ()

      let gen_proofs =
        let open Quickcheck.Generator.Let_syntax in
        let data_gen =
          let%bind statements =
            One_or_two.gen Transaction_snark.Statement.gen
          in
          let%map {fee; prover} = Fee_with_prover.gen in
          let message = Coda_base.Sok_message.create ~fee ~prover in
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
          let%bind {fee; prover} = Fee_with_prover.gen in
          let%map invalid_prover =
            Quickcheck.Generator.filter Signature_lib.Public_key.Compressed.gen
              ~f:(Signature_lib.Public_key.Compressed.( <> ) prover)
          in
          let sok_digest =
            Coda_base.Sok_message.(digest (create ~fee ~prover:invalid_prover))
          in
          let message = Coda_base.Sok_message.create ~fee ~prover in
          ( One_or_two.map statements ~f:(fun statement ->
                Ledger_proof.create ~statement ~sok_digest
                  ~proof:Proof.transaction_dummy )
          , message )
        in
        Envelope.Incoming.gen data_gen

      let run_test proof_lists =
        let%bind verifier =
          Verifier.create ~logger ~proof_level
            ~pids:(Child_processes.Termination.create_pid_table ())
            ~conf_dir:None
        in
        let batcher = create verifier in
        Deferred.List.iter proof_lists ~f:(fun (invalid_proofs, proof_list) ->
            let%map r = verify' batcher proof_list in
            let (`Invalid ps) = Or_error.ok_exn r in
            assert (Work_key.Set.equal ps invalid_proofs) )

      let gen ~(valid_count : [`Any | `Count of int])
          ~(invalid_count : [`Any | `Count of int]) =
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
