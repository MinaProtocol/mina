open Core
open Async

module Inputs = struct
  module Worker_state = struct
    include Unit

    let create () = Deferred.unit

    let worker_wait_time = 0.5
  end

  module Proof = struct
    type t =
      Transaction_snark.Statement.t
      * Nanobit_base.Sok_message.Digest.Stable.V1.t
    [@@deriving bin_io]
  end

  module Statement = Transaction_snark.Statement

  module Public_key = struct
    include Signature_lib.Public_key.Compressed

    let arg_type = Cli_lib.public_key_compressed
  end

  module Super_transaction = Nanobit_base.Super_transaction
  module Sparse_ledger = Nanobit_base.Sparse_ledger

  let perform_single () ~message s =
    Ok
      ( Snark_work_lib.Work.Single.Spec.statement s
      , Nanobit_base.Sok_message.digest message )
end

module Worker = Worker.Make (Inputs)

let command_name = "snark-worker-debug"
