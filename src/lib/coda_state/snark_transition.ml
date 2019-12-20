open Core_kernel
open Coda_base

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
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
        ; coinbase_amount: 'amount }
      [@@deriving bin_io, to_yojson, sexp, fields, version]
    end
  end]

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
    ; ledger_proof: Proof.t option
    ; proposer: 'proposer_pk
    ; coinbase_amount: 'amount }
  [@@deriving sexp, to_yojson, fields]
end

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Blockchain_state.Value.Stable.V1.t
        , Consensus.Data.Consensus_transition.Value.Stable.V1.t
        , Sok_message.Digest.Stable.V1.t
        , Currency.Amount.Stable.V1.t
        , Signature_lib.Public_key.Compressed.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving to_yojson, sexp]
end

[%%define_locally
Poly.
  ( blockchain_state
  , consensus_transition
  , ledger_proof
  , sok_digest
  , supply_increase
  , proposer
  , coinbase_amount )]

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
    ~coinbase_amount () : Value.t =
  { blockchain_state
  ; consensus_transition
  ; ledger_proof
  ; sok_digest
  ; supply_increase
  ; proposer
  ; coinbase_amount }

let genesis ~genesis_ledger : value =
  let genesis_ledger = Lazy.force genesis_ledger in
  { Poly.blockchain_state=
      Blockchain_state.genesis
        ~genesis_ledger_hash:(Ledger.merkle_root genesis_ledger)
  ; consensus_transition= Consensus.Data.Consensus_transition.genesis
  ; supply_increase= Currency.Amount.zero
  ; sok_digest=
      Sok_message.digest
        { fee= Currency.Fee.zero
        ; prover=
            Account.public_key (List.hd_exn (Ledger.to_list genesis_ledger)) }
  ; ledger_proof= None
  ; proposer= Signature_lib.Public_key.Compressed.empty
  ; coinbase_amount= Currency.Amount.zero }

let to_hlist
    { Poly.blockchain_state
    ; consensus_transition
    ; sok_digest
    ; supply_increase
    ; ledger_proof
    ; proposer
    ; coinbase_amount } =
  Snarky.H_list.
    [ blockchain_state
    ; consensus_transition
    ; sok_digest
    ; supply_increase
    ; ledger_proof
    ; proposer
    ; coinbase_amount ]

let of_hlist
    ([ blockchain_state
     ; consensus_transition
     ; sok_digest
     ; supply_increase
     ; ledger_proof
     ; proposer
     ; coinbase_amount ] :
      (unit, _) Snarky.H_list.t) =
  { Poly.blockchain_state
  ; consensus_transition
  ; sok_digest
  ; supply_increase
  ; ledger_proof
  ; proposer
  ; coinbase_amount }

let typ =
  let open Snark_params.Tick.Typ in
  let ledger_proof =
    { store= Store.return
    ; read= Read.return
    ; check= (fun _ -> Snark_params.Tick.Checked.return ())
    ; alloc= Alloc.return None }
  in
  of_hlistable ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
    [ Blockchain_state.typ
    ; Consensus.Data.Consensus_transition.typ
    ; Sok_message.Digest.typ
    ; Currency.Amount.typ
    ; ledger_proof
    ; Signature_lib.Public_key.Compressed.typ
    ; Currency.Amount.typ ]
