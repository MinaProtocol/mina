open Core_kernel
open Async_kernel
open Network_peer

(*
module Batcher : sig
  type ('proof, 'result) t [@@deriving sexp]

  module Outcome : sig
    type ('proof, 'result) t =
      { valid : 'result list
      ; invalid: 'proof list
      }
    [@@deriving sexp]
  end 

  val create
(* The comparison function for proofs is to group things so that
   things which are more likely to jointly fail are grouped together.
   In practice, we sort by sender. *)
    : ?compare_proof:('a -> 'a -> int)
    -> ('a list -> ('result, unit) Result.t Deferred.Or_error.t)
    -> ('a, 'result) t 

  val verify :
       ('proof, 'result) t
    -> ('proof list -> ('proof, 'result) Outcome.t Deferred.Or_error.t)
end = struct
*)
module Outcome = struct
  type ('proof, 'result) t = {valid: 'result list; invalid: 'proof list}
  [@@deriving sexp]

  let valid valid = {valid; invalid= []}

  let invalid invalid = {invalid; valid= []}

  let add_valid t v = {t with valid= v :: t.valid}

  let empty = {valid= []; invalid= []}

  let append t1 t2 =
    {valid= t1.valid @ t2.valid; invalid= t1.invalid @ t2.invalid}
end

type ('proof, 'result) state =
  | Waiting
  | Verifying of
      { out_for_verification: 'proof list
      ; next_finished:
          ('proof, 'result) Outcome.t Or_error.t Ivar.t sexp_opaque }
[@@deriving sexp]

type ('proof, 'result) t =
  { mutable state: ('proof, 'result) state
  ; queue: 'proof Queue.t
  ; compare_proof: ('proof -> 'proof -> int) option
  ; verifier:
      ('proof list -> ('result, unit) Result.t Deferred.Or_error.t) sexp_opaque
  }
[@@deriving sexp]

let create ?compare_proof verifier =
  {state= Waiting; queue= Queue.create (); compare_proof; verifier}

let call_verifier t (ps : 'proof list) = t.verifier ps

(*Worst case (if all the proofs are invalid): log n * (2^(log n) + 1)
  In the average case this should show better performance.
  We need to implement the trusted/untrusted batches from the snark pool batching RFC #4882 to avoid possible DoS/DDoS here*)
let find_invalid_proofs (type p r) (ps : p list) (v : (p, r) t) :
    (p, r) Outcome.t Deferred.Or_error.t =
  let open Deferred.Or_error.Let_syntax in
  let rec go ps =
    match ps with
    | [] ->
        return Outcome.empty
    | [p] ->
        (* If we are inside [go], we know there is at least one element of [ps]
           which is invalid, so [p] itself must be invalid. *)
        return (Outcome.invalid [p])
    | ps -> (
        let length = List.length ps in
        let left = List.take ps (length / 2) in
        let right = List.drop ps (length / 2) in
        let%bind res_l = call_verifier v left in
        let%bind res_r = call_verifier v right in
        match (res_l, res_r) with
        | Ok res_l, Error () ->
            let%map res = go right in
            Outcome.add_valid res res_l
        | Error (), Ok res_r ->
            let%map res = go left in
            Outcome.add_valid res res_r
        | Error (), Error () ->
            let%bind l = go left in
            let%map r = go right in
            Outcome.append l r
        | Ok l, Ok r ->
            return (Outcome.valid [l; r]) )
  in
  go ps

(* When new proofs come in put them in the queue.
      If state = Waiting, verify those proofs immediately.
      Whenever the verifier returns, if the queue is nonempty, flush it into the verifier.
  *)

let rec start_verifier (t : ('proof, 'r) t) finished =
  if Queue.is_empty t.queue then (
    (* we looped in the else after verifier finished but no pending work. *)
    t.state <- Waiting ;
    Ivar.fill finished (Ok Outcome.empty) )
  else
    let out_for_verification = Queue.to_list t.queue in
    let next_finished = Ivar.create () in
    t.state <- Verifying {next_finished; out_for_verification} ;
    Queue.clear t.queue ;
    let res = call_verifier t out_for_verification in
    upon res (fun verification_res ->
        let any_invalid_proofs =
          let open Deferred.Or_error.Let_syntax in
          match verification_res with
          | Ok (Ok res) ->
              return (Outcome.valid [res])
          | Ok (Error ()) ->
              (*ordering by sender with the assumption that all the proofs from a malicious sender would be invalid and therefore will increase the probability of them being in a single batch*)
              let ordered_list =
                match t.compare_proof with
                | None ->
                    out_for_verification
                | Some compare ->
                    List.sort out_for_verification ~compare
                (*:(fun e1 e2 ->
                      Envelope.Sender.compare e1.sender e2.sender ) *)
              in
              (*Find invalid proofs*)
              find_invalid_proofs ordered_list t
          | Error e ->
              Deferred.return (Error e)
        in
        upon any_invalid_proofs (fun y -> Ivar.fill finished y) ) ;
    start_verifier t next_finished

let verify (type p r) (t : (p, r) t) (proofs : p list) :
    (p, r) Outcome.t Deferred.Or_error.t =
  Queue.enqueue_all t.queue proofs ;
  match t.state with
  | Verifying {next_finished; _} ->
      Ivar.read next_finished
  | Waiting ->
      let finished = Ivar.create () in
      start_verifier t finished ; Ivar.read finished

type ('a, 'b) batcher = ('a, 'b) t [@@deriving sexp]

let compare_envelope (e1 : _ Envelope.Incoming.t) (e2 : _ Envelope.Incoming.t)
    =
  Envelope.Sender.compare e1.sender e2.sender

module Transaction_pool = struct
  open Coda_base

  type t =
    ( Command_transaction.Verifiable.t list Envelope.Incoming.t
    , Command_transaction.Valid.t list )
    batcher
  [@@deriving sexp]

  let create verifier : t =
    create ~compare_proof:compare_envelope (fun xs ->
        Deferred.Or_error.map
          (Verifier.verify_commands verifier
             (List.concat_map xs ~f:Envelope.Incoming.data))
          ~f:(Result.map_error ~f:ignore) )

  let verify (t : t) = verify t
end

module Snark_pool = struct
  type proof_envelope =
    (Ledger_proof.t One_or_two.t * Coda_base.Sok_message.t) Envelope.Incoming.t
  [@@deriving sexp]

  type t = (proof_envelope, unit) batcher [@@deriving sexp]

  let verify (t : t) = verify t

  let create verifier : t =
    create ~compare_proof:compare_envelope (fun ps ->
        let ps =
          List.concat_map ps ~f:(fun env ->
              let ps, message = env.data in
              One_or_two.map ps ~f:(fun p -> (p, message))
              |> One_or_two.to_list )
        in
        let open Deferred.Or_error.Let_syntax in
        match%map Verifier.verify_transaction_snarks verifier ps with
        | true ->
            Ok ()
        | false ->
            Error () )

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

  let verify (t : t) ps =
    let open Deferred.Or_error.Let_syntax in
    let%map {Outcome.invalid; valid= _} = verify t ps in
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
            let%map r = verify batcher proof_list in
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
