open Core
open Async
open Signature_lib

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

module Inputs = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type t = {m: (module S); cache: Cache.t}

    let create () =
      let%map proving = Snark_keys.transaction_proving ()
      and verification = Snark_keys.transaction_verification () in
      { m=
          ( module Transaction_snark.Make (struct
            let keys = {Transaction_snark.Keys.proving; verification}
          end)
          : S )
      ; cache= Cache.create () }

    let worker_wait_time = 5.
  end

  module Proof = Transaction_snark.Stable.V1
  module Statement = Transaction_snark.Statement.Stable.V1

  module Public_key = struct
    include Public_key.Compressed

    let arg_type = Cli_lib.Arg_type.public_key_compressed
  end

  module Transaction = Coda_base.Transaction.Stable.V1
  module Sparse_ledger = Coda_base.Sparse_ledger.Stable.V1
  module Pending_coinbase = Coda_base.Pending_coinbase.Stable.V1
  module Transaction_witness = Coda_base.Transaction_witness.Stable.V1

  type single_spec =
    ( Statement.t
    , Transaction.t
    , Transaction_witness.t
    , Transaction_snark.t )
    Snark_work_lib.Work.Single.Spec.t
  [@@deriving sexp]

  (* TODO: Use public_key once SoK is implemented *)
  let perform_single ({m= (module M); cache} : Worker_state.t) ~message =
    let open Snark_work_lib in
    let sok_digest = Coda_base.Sok_message.digest message in
    fun (single : single_spec) ->
      let statement = Work.Single.Spec.statement single in
      let process k =
        let start = Time.now () in
        match k () with
        | Error e ->
            Logger.error (Logger.create ()) ~module_:__MODULE__
              ~location:__LOC__
              ~metadata:
                [ ( "spec"
                  , `String (Sexp.to_string (sexp_of_single_spec single)) ) ]
              "Worker failed: %s" (Error.to_string_hum e) ;
            Error.raise e
        | Ok res ->
            Cache.add cache ~statement ~proof:res ;
            let total = Time.abs_diff (Time.now ()) start in
            Ok (res, total)
      in
      match Cache.find cache statement with
      | Some proof -> Or_error.return (proof, Time.Span.zero)
      | None -> (
        match single with
        | Work.Single.Spec.Transition (input, t, (w : Transaction_witness.t))
          ->
            process (fun () ->
                Or_error.try_with (fun () ->
                    M.of_transaction ~sok_digest ~source:input.Statement.source
                      ~target:input.target t
                      ~pending_coinbase_stack_state:
                        input.Statement.pending_coinbase_stack_state
                      (unstage (Coda_base.Sparse_ledger.handler w.ledger)) ) )
        | Merge (_, proof1, proof2) ->
            process (fun () -> M.merge ~sok_digest proof1 proof2) )
end

module Worker = Worker.Make (Inputs)
