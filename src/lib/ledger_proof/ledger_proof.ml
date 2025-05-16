open Core_kernel
open Mina_base

module type S = Ledger_proof_intf.S

module Poly = struct
  type ( 'ledger_hash
       , 'amount
       , 'pending_coinbase
       , 'fee_excess
       , 'sok_digest
       , 'local_state
       , 'proof )
       t =
    ( ( 'ledger_hash
      , 'amount
      , 'pending_coinbase
      , 'fee_excess
      , 'sok_digest
      , 'local_state )
      Mina_state.Snarked_ledger_state.Poly.Stable.V2.t
    , 'proof )
    Proof_carrying_data.t

  let create ~(statement : Mina_state.Snarked_ledger_state.t) ~sok_digest ~proof
      : _ t =
    { Proof_carrying_data.proof; data = { statement with sok_digest } }

  let statement (t : _ t) = { t.data with sok_digest = () }

  let underlying_proof (t : _ t) = t.proof
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = Transaction_snark.Stable.V2.t
    [@@deriving compare, equal, sexp, yojson, hash]

    let to_latest = Fn.id
  end
end]

let statement_with_sok (t : t) = Transaction_snark.statement_with_sok t

let statement_target (t : Mina_state.Snarked_ledger_state.t) = t.target

let statement_with_sok_target (t : Mina_state.Snarked_ledger_state.With_sok.t) =
  t.target

let snarked_ledger_hash =
  Fn.compose Mina_state.Snarked_ledger_state.snarked_ledger_hash Poly.statement

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

  let read_proof_from_disk ({ Proof_carrying_data.data = statement; proof } : t)
      : Stable.Latest.t =
    Transaction_snark.create ~statement
      ~proof:(Proof_cache_tag.read_proof_from_disk proof)
end

module For_tests = struct
  let mk_dummy_proof statement =
    Poly.create ~statement ~sok_digest:Sok_message.Digest.default
      ~proof:(Lazy.force Proof.transaction_dummy)

  module Cached = struct
    let mk_dummy_proof statement =
      Poly.create ~statement ~sok_digest:Sok_message.Digest.default
        ~proof:(Lazy.force Proof.For_tests.transaction_dummy_tag)
  end
end
