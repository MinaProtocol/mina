open Core
open Async

module Proof = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          Transaction_snark.Statement.Stable.V1.t
          * Coda_base.Sok_message.Digest.Stable.V1.t
        [@@deriving bin_io, sexp, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

module Inputs = struct
  module Worker_state = struct
    include Unit

    let create () = Deferred.unit

    let worker_wait_time = 0.1
  end

  module Statement = Transaction_snark.Statement.Stable.V1

  module Public_key = struct
    include Signature_lib.Public_key.Compressed

    let arg_type = Cli_lib.Arg_type.public_key_compressed
  end

  module Transaction = Coda_base.Transaction.Stable.Latest
  module Sparse_ledger = Coda_base.Sparse_ledger.Stable.V1
  module Pending_coinbase = Coda_base.Pending_coinbase.Stable.V1
  module Transaction_witness = Coda_base.Transaction_witness.Stable.V1
  module Proof = Proof.Stable.V1

  let perform_single () ~message s =
    Ok
      ( ( Snark_work_lib.Work.Single.Spec.statement s
        , Coda_base.Sok_message.digest message )
      , Time.Span.zero )
end

module Worker = Worker.Make (Inputs)
