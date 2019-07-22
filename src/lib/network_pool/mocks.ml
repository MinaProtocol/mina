open Core_kernel
open Signature_lib

let trust_system = Trust_system.null ()

module Ledger_proof = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = int [@@deriving bin_io, sexp, yojson, version {unnumbered}]
      end

      include T
    end
  end

  include Stable.V1.T
end

module Transaction_snark_work = struct
  type t =
    { fee: Currency.Fee.t
    ; proofs: Ledger_proof.t list
    ; prover: Public_key.Compressed.t }

  module Statement = struct
    type t = Transaction_snark.Statement.Stable.Latest.t list
    [@@deriving sexp, hash, compare, bin_io, yojson]

    let gen = List.quickcheck_generator Transaction_snark.Statement.gen

    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Transaction_snark.Statement.Stable.Latest.t list
          [@@deriving
            sexp, hash, compare, bin_io, yojson, version {unnumbered}]
        end

        include T
        include Hashable.Make_binable (T)
      end
    end

    module Latest = Stable.V1
    include Hashable.Make (Stable.V1.T)
  end

  module Checked = struct
    type nonrec t = t

    let create_unsafe = Fn.id
  end
end

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
