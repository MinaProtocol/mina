open Core_kernel
open Coda_base

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ( 'blockchain_state
             , 'consensus_transition
             , 'sok_digest
             , 'amount
             , 'proposer_pk )
             t =
          { blockchain_state: 'blockchain_state
          ; consensus_transition: 'consensus_transition
          ; sok_digest: 'sok_digest
          ; supply_increase: 'amount
          ; ledger_proof: Proof.Stable.V1.t option
          ; proposer: 'proposer_pk
          ; coinbase: 'amount }
        [@@deriving bin_io, sexp, fields, version]
      end

      include T
    end

    module Latest = V1
  end

  type ( 'blockchain_state
       , 'consensus_transition
       , 'sok_digest
       , 'amount
       , 'proposer_pk )
       t =
        ( 'blockchain_state
        , 'consensus_transition
        , 'sok_digest
        , 'amount
        , 'proposer_pk )
        Stable.Latest.t =
    { blockchain_state: 'blockchain_state
    ; consensus_transition: 'consensus_transition
    ; sok_digest: 'sok_digest
    ; supply_increase: 'amount
    ; ledger_proof: Proof.Stable.V1.t option
    ; proposer: 'proposer_pk
    ; coinbase: 'amount }
  [@@deriving sexp, fields]
end

module Value = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t =
          ( Blockchain_state.Value.Stable.V1.t
          , Consensus.Data.Consensus_transition.Value.Stable.V1.t
          , Sok_message.Digest.Stable.V1.t
          , Currency.Amount.Stable.V1.t
          , Signature_lib.Public_key.Compressed.Stable.V1.t )
          Poly.Stable.V1.t
        [@@deriving bin_io, sexp, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving sexp]
end

let ( blockchain_state
    , consensus_transition
    , ledger_proof
    , sok_digest
    , supply_increase
    , proposer
    , coinbase ) =
  Poly.
    ( blockchain_state
    , consensus_transition
    , ledger_proof
    , sok_digest
    , supply_increase
    , proposer
    , coinbase )

type value = Value.t

type var =
  ( Blockchain_state.var
  , Consensus.Data.Consensus_transition.var
  , Sok_message.Digest.Checked.t
  , Currency.Amount.var
  , Signature_lib.Public_key.Compressed.var )
  Poly.t

let create_value ?(sok_digest = Sok_message.Digest.default) ?ledger_proof
    ~supply_increase ~blockchain_state ~consensus_transition ~proposer
    ~coinbase () : Value.t =
  { blockchain_state
  ; consensus_transition
  ; ledger_proof
  ; sok_digest
  ; supply_increase
  ; proposer
  ; coinbase }

let genesis =
  { Poly.blockchain_state= Blockchain_state.genesis
  ; consensus_transition= Consensus.Data.Consensus_transition.genesis
  ; supply_increase= Currency.Amount.zero
  ; sok_digest=
      Sok_message.digest
        { fee= Currency.Fee.zero
        ; prover=
            Account.public_key (List.hd_exn (Ledger.to_list Genesis_ledger.t))
        }
  ; ledger_proof= None
  ; proposer= Signature_lib.Public_key.Compressed.empty
  ; coinbase= Currency.Amount.zero }

let typ =
  let open Snark_params.Tick.Typ in
  let store
      { Poly.blockchain_state
      ; consensus_transition
      ; sok_digest
      ; supply_increase
      ; ledger_proof
      ; proposer
      ; coinbase } =
    let open Store.Let_syntax in
    let%map blockchain_state = Blockchain_state.typ.store blockchain_state
    and consensus_transition =
      Consensus.Data.Consensus_transition.typ.store consensus_transition
    and sok_digest = Sok_message.Digest.typ.store sok_digest
    and supply_increase = Currency.Amount.typ.store supply_increase
    and proposer = Signature_lib.Public_key.Compressed.typ.store proposer
    and coinbase = Currency.Amount.typ.store coinbase in
    { Poly.blockchain_state
    ; consensus_transition
    ; sok_digest
    ; supply_increase
    ; ledger_proof
    ; proposer
    ; coinbase }
  in
  let read
      { Poly.blockchain_state
      ; consensus_transition
      ; sok_digest
      ; supply_increase
      ; ledger_proof
      ; proposer
      ; coinbase } =
    let open Read.Let_syntax in
    let%map blockchain_state = Blockchain_state.typ.read blockchain_state
    and consensus_transition =
      Consensus.Data.Consensus_transition.typ.read consensus_transition
    and sok_digest = Sok_message.Digest.typ.read sok_digest
    and supply_increase = Currency.Amount.typ.read supply_increase
    and proposer = Signature_lib.Public_key.Compressed.typ.read proposer
    and coinbase = Currency.Amount.typ.read coinbase in
    { Poly.blockchain_state
    ; consensus_transition
    ; sok_digest
    ; supply_increase
    ; ledger_proof
    ; proposer
    ; coinbase }
  in
  let check
      { Poly.blockchain_state
      ; consensus_transition
      ; sok_digest
      ; supply_increase
      ; ledger_proof= _
      ; proposer
      ; coinbase= _ } =
    let open Snark_params.Tick in
    let%map () = Blockchain_state.typ.check blockchain_state
    and () = Consensus.Data.Consensus_transition.typ.check consensus_transition
    and () = Sok_message.Digest.typ.check sok_digest
    and () = Currency.Amount.typ.check supply_increase
    and () = Signature_lib.Public_key.Compressed.typ.check proposer in
    ()
  in
  let alloc =
    let open Alloc.Let_syntax in
    let%map blockchain_state = Blockchain_state.typ.alloc
    and consensus_transition = Consensus.Data.Consensus_transition.typ.alloc
    and sok_digest = Sok_message.Digest.typ.alloc
    and supply_increase = Currency.Amount.typ.alloc
    and proposer = Signature_lib.Public_key.Compressed.typ.alloc
    and coinbase = Currency.Amount.typ.alloc in
    { Poly.blockchain_state
    ; consensus_transition
    ; sok_digest
    ; supply_increase
    ; ledger_proof= None
    ; proposer
    ; coinbase }
  in
  {Snarky.Types.Typ.store; read; check; alloc}
