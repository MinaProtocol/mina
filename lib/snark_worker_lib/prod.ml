open Core
open Async
open Signature_lib

module Inputs = struct
  module Worker_state = struct
    module type S = Transaction_snark.S

    type t = (module S)

    let create () =
      let%map proving = Snark_keys.transaction_proving ()
      and verification = Snark_keys.transaction_verification () in
      ( module Transaction_snark.Make (struct
        let keys = {Transaction_snark.Keys.proving; verification}
      end)
      : S )

    let worker_wait_time = 10.
  end

  module Proof = Transaction_snark
  module Statement = Transaction_snark.Statement

  module Public_key = struct
    include Public_key.Compressed

    let arg_type = Cli_lib.public_key_compressed
  end

  module Super_transaction = Coda_base.Super_transaction
  module Sparse_ledger = Coda_base.Sparse_ledger

  (* TODO: Use public_key once SoK is implemented *)
  let perform_single ((module M): Worker_state.t) ~message =
    let open Snark_work_lib in
    let sok_digest = Coda_base.Sok_message.digest message in
    function
      | Work.Single.Spec.Transition (input, t, l) ->
          let start = Time.now () in
          let res =
            M.of_transition ~sok_digest ~source:input.Statement.source
              ~target:input.target t
              (unstage (Coda_base.Sparse_ledger.handler l))
          in
          let total = Time.abs_diff (Time.now ()) start in
          Or_error.return (res, total)
      | Merge (_, proof1, proof2) ->
          let open Or_error.Let_syntax in
          let start = Time.now () in
          let%map res = M.merge ~sok_digest proof1 proof2 in
          let total = Time.abs_diff (Time.now ()) start in
          (res, total)
end

module Worker = Worker.Make (Inputs)

let command_name = "snark-worker-prod"
