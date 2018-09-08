open Core
open Async

module Inputs = struct
  module Worker_state = struct
    include Unit

    let create () = Deferred.unit

    let worker_wait_time = 1.
  end

  module Proof = struct
    type t =
      Transaction_snark.Statement.t
      * Nanobit_base.Sok_message.Digest.Stable.V1.t
    [@@deriving bin_io, sexp]
  end

  module Statement = Transaction_snark.Statement

  module Public_key = struct
    include Signature_lib.Public_key.Compressed

    let arg_type = Cli_lib.public_key_compressed
  end

  module Super_transaction = Nanobit_base.Super_transaction
  module Sparse_ledger = Nanobit_base.Sparse_ledger
  open Snark_work_lib

  let create_transaction_snark ((statement: Statement.t), sok_digest) =
    Transaction_snark.create ~source:statement.source ~target:statement.target
      ~proof_type:statement.proof_type ~fee_excess:statement.fee_excess
      ~sok_digest ~proof:Dummy_values.Tock.proof

  type single_spec =
    ( Statement.t
    , Super_transaction.t
    , Sparse_ledger.t
    , Proof.t )
    Work.Single.Spec.t
  [@@deriving sexp]

  let perform_single () ~message spec : Proof.t Or_error.t =
    let res =
      match spec with
      | Work.Single.Spec.Transition ((statement: Statement.t), t, ledger) ->
          Transaction_snark.check_transition ~sok_message:message
            ~source:statement.source ~target:statement.target t
            (unstage (Nanobit_base.Sparse_ledger.handler ledger))
      | Merge (_, p1, p2) ->
          let proof1 = create_transaction_snark p1 in
          let proof2 = create_transaction_snark p2 in
          Transaction_snark.check_merge ~sok_message:message proof1 proof2
    in
    let open Or_error.Let_syntax in
    let%bind s = res in
    let%map () =
      let expected = Work.Single.Spec.statement spec in
      if Transaction_snark.Statement.equal expected s then Ok ()
      else
        Or_error.errorf
          !"Disagreeing statements: %{sexp:Statement.t} vs %{sexp:Statement.t}\n\
            given %{sexp:single_spec}"
          expected s spec
    in
    (s, Nanobit_base.Sok_message.digest message)
end

module Worker = Worker.Make (Inputs)

let command_name = "snark-worker-debug"
