open Core_kernel
open Mina_base

module type S = Ledger_proof_intf.S

module Prod : Ledger_proof_intf.S with type t = Transaction_snark.t = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Transaction_snark.Stable.V2.t
      [@@deriving compare, equal, sexp, yojson, hash]

      let to_latest = Fn.id
    end
  end]

  let statement (t : t) = Transaction_snark.statement t

  let statement_with_sok (t : t) = Transaction_snark.statement_with_sok t

  let sok_digest = Transaction_snark.sok_digest

  let statement_target (t : Mina_state.Snarked_ledger_state.t) = t.target

  let statement_with_sok_target (t : Mina_state.Snarked_ledger_state.With_sok.t)
      =
    t.target

  let underlying_proof = Transaction_snark.proof

  let create ~statement ~sok_digest ~proof =
    Transaction_snark.create ~statement:{ statement with sok_digest } ~proof
end

include Prod

module For_tests = struct
  let mk_dummy_proof statement =
    create ~statement ~sok_digest:Sok_message.Digest.default
      ~proof:Proof.transaction_dummy
end
