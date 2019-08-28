let trust_system = Trust_system.null ()

module Transaction_snark_work = Transaction_snark_work.Make (Ledger_proof.Debug)
module Ledger_proof = Ledger_proof.Debug.Stable.V1

module Transition_frontier = struct
  type t = string

  let create () : t = ""

  module Extensions = struct
    module Work = Transaction_snark_work.Statement
  end

  let snark_pool_refcount_pipe _ =
    let reader, _writer =
      Pipe_lib.Broadcast_pipe.create
        (0, Transaction_snark_work.Statement.Stable.V1.Table.create ())
    in
    reader
end
