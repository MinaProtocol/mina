open Core
open Async

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
  end

  module Proof = Transaction_snark
  module Statement = Transaction_snark.Statement
  module Public_key = struct
    include Nanobit_base.Public_key.Compressed
    let arg_type = Cli_lib.public_key_compressed
  end
  module Super_transaction = Nanobit_base.Super_transaction
  module Sparse_ledger = Nanobit_base.Sparse_ledger

  (* TODO: Use public_key once SoK is implemented *)
  let perform_single ((module M) : Worker_state.t) ~message:_ =
    let open Snark_work_lib in
    function
      | Work.Single.Spec.Transition (input, t, l) ->
          Or_error.return
            (M.of_transition input.Statement.source input.target t
              (unstage (Nanobit_base.Sparse_ledger.handler l)))
      | Merge (_, proof1, proof2) -> M.merge proof1 proof2
end

module Worker = Worker.Make(Inputs)
