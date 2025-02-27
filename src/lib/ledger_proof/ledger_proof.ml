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

  let snarked_ledger_hash =
    Fn.compose Mina_state.Snarked_ledger_state.snarked_ledger_hash statement

  let create ~statement ~sok_digest ~proof =
    Transaction_snark.create ~statement:{ statement with sok_digest } ~proof

  module Cached = struct
    type t =
      ( Mina_state.Snarked_ledger_state.With_sok.t
      , Proof_cache_tag.t )
      Proof_carrying_data.t

    let write_proof_to_disk ~proof_cache_db (t : Stable.Latest.t) : t =
      { Proof_carrying_data.proof =
          Proof_cache_tag.write_proof_to_disk proof_cache_db
            (Transaction_snark.proof t)
      ; data = Transaction_snark.statement_with_sok t
      }

    let read_proof_from_disk
        ({ Proof_carrying_data.data = statement; proof } : t) : Stable.Latest.t
        =
      Transaction_snark.create ~statement
        ~proof:(Proof_cache_tag.read_proof_from_disk proof)

    let statement (t : t) = { t.data with sok_digest = () }

    let sok_digest (t : t) = t.data.sok_digest

    let underlying_proof (t : t) = t.proof

    let create ~(statement : Mina_state.Snarked_ledger_state.t) ~sok_digest
        ~proof : t =
      { Proof_carrying_data.proof; data = { statement with sok_digest } }
  end
end

include Prod

module For_tests = struct
  let mk_dummy_proof statement =
    create ~statement ~sok_digest:Sok_message.Digest.default
      ~proof:(Lazy.force Proof.transaction_dummy)

  module Cached = struct
    let mk_dummy_proof statement =
      Cached.create ~statement ~sok_digest:Sok_message.Digest.default
        ~proof:(Lazy.force Proof_cache_tag.For_tests.transaction_dummy)
  end
end
