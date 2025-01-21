open Core_kernel
open Mina_base

module type S = Ledger_proof_intf.S

module Prod :
  Ledger_proof_intf.S with type 'a Poly.t = 'a Transaction_snark.Poly.t = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = Transaction_snark.Stable.V2.t
      [@@deriving compare, equal, sexp, yojson, hash]

      let to_latest = Fn.id
    end
  end]

  module Poly = Transaction_snark.Poly

  let statement = Transaction_snark.statement

  let statement_with_sok = Transaction_snark.statement_with_sok

  let sok_digest = Transaction_snark.sok_digest

  let statement_target (t : Mina_state.Snarked_ledger_state.t) = t.target

  let statement_with_sok_target (t : Mina_state.Snarked_ledger_state.With_sok.t)
      =
    t.target

  let underlying_proof = Transaction_snark.proof

  let snarked_ledger_hash p =
    Mina_state.Snarked_ledger_state.snarked_ledger_hash (statement p)

  let create ~statement ~sok_digest ~proof =
    Transaction_snark.create ~statement:{ statement with sok_digest } ~proof

  module Cached = struct
    type t = Proof_cache_tag.t Poly.t

    let generate ~proof_cache_db t =
      { t with
        Proof_carrying_data.proof =
          Proof_cache_tag.generate proof_cache_db t.Proof_carrying_data.proof
      }

    let unwrap t =
      { t with
        Proof_carrying_data.proof =
          Proof_cache_tag.unwrap t.Proof_carrying_data.proof
      }
  end
end

include Prod

module For_tests = struct
  let mk_dummy_proof statement =
    create ~statement ~sok_digest:Sok_message.Digest.default
      ~proof:(Lazy.force Proof.transaction_dummy)

  let mk_dummy_proof_cached statement =
    create ~statement ~sok_digest:Sok_message.Digest.default
      ~proof:(Lazy.force Proof_cache_tag.For_tests.transaction_dummy)
end
