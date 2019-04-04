open Core_kernel

module type Consensus_data_intf = sig
  type value [@@deriving bin_io, sexp]

  include Snark_params.Tick.Snarkable.S with type value := value

  val genesis : value
end

module type Inputs_intf = sig
  module Genesis_ledger : sig
    val t : Ledger.t
  end

  module Blockchain_state : Blockchain_state.S

  module Consensus_data : Consensus_data_intf
end

module type S = sig
  module Blockchain_state : Blockchain_state.S

  module Consensus_data : Consensus_data_intf

  type ( 'blockchain_state
       , 'consensus_data
       , 'sok_digest
       , 'amount
       , 'proposer_pk ) t
  [@@deriving sexp]

  type value =
    ( Blockchain_state.Value.t
    , Consensus_data.value
    , Sok_message.Digest.t
    , Currency.Amount.t
    , Signature_lib.Public_key.Compressed.t )
    t
  [@@deriving bin_io, sexp]

  type var =
    ( Blockchain_state.var
    , Consensus_data.var
    , Sok_message.Digest.Checked.t
    , Currency.Amount.var
    , Signature_lib.Public_key.Compressed.var )
    t

  include
    Snark_params.Tick.Snarkable.S with type value := value and type var := var

  val create_value :
       ?sok_digest:Sok_message.Digest.t
    -> ?ledger_proof:Proof.t
    -> supply_increase:Currency.Amount.t
    -> blockchain_state:Blockchain_state.Value.t
    -> consensus_data:Consensus_data.value
    -> proposer:Signature_lib.Public_key.Compressed.t
    -> coinbase:Currency.Amount.t
    -> unit
    -> value

  val blockchain_state : ('a, _, _, _, _) t -> 'a

  val consensus_data : (_, 'a, _, _, _) t -> 'a

  val sok_digest : (_, _, 'a, _, _) t -> 'a

  val supply_increase : (_, _, _, 'a, _) t -> 'a

  val coinbase : (_, _, _, 'a, _) t -> 'a

  val ledger_proof : _ t -> Proof.t option

  val proposer : (_, _, _, _, 'a) t -> 'a

  val genesis : value
end

module Make (Inputs : Inputs_intf) :
  S
  with module Blockchain_state = Inputs.Blockchain_state
   and module Consensus_data = Inputs.Consensus_data = struct
  include Inputs

  type ( 'blockchain_state
       , 'consensus_data
       , 'sok_digest
       , 'amount
       , 'proposer_pk ) t =
    { blockchain_state: 'blockchain_state
    ; consensus_data: 'consensus_data
    ; sok_digest: 'sok_digest
    ; supply_increase: 'amount
    ; ledger_proof: Proof.t option
    ; proposer: 'proposer_pk
    ; coinbase: 'amount }
  [@@deriving bin_io, sexp, fields]

  type value =
    ( Blockchain_state.Value.Stable.V1.t
    , Consensus_data.value
    , Sok_message.Digest.Stable.V1.t
    , Currency.Amount.Stable.V1.t
    , Signature_lib.Public_key.Compressed.Stable.V1.t )
    t
  [@@deriving bin_io, sexp]

  type var =
    ( Blockchain_state.var
    , Consensus_data.var
    , Sok_message.Digest.Checked.t
    , Currency.Amount.var
    , Signature_lib.Public_key.Compressed.var )
    t

  let create_value ?(sok_digest = Sok_message.Digest.default) ?ledger_proof
      ~supply_increase ~blockchain_state ~consensus_data ~proposer ~coinbase ()
      =
    { blockchain_state
    ; consensus_data
    ; ledger_proof
    ; sok_digest
    ; supply_increase
    ; proposer
    ; coinbase }

  let typ =
    let open Snark_params.Tick.Typ in
    let store
        { blockchain_state
        ; consensus_data
        ; sok_digest
        ; supply_increase
        ; ledger_proof
        ; proposer
        ; coinbase } =
      let open Store.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.store blockchain_state
      and consensus_data = Consensus_data.typ.store consensus_data
      and sok_digest = Sok_message.Digest.typ.store sok_digest
      and supply_increase = Currency.Amount.typ.store supply_increase
      and proposer = Signature_lib.Public_key.Compressed.typ.store proposer
      and coinbase = Currency.Amount.typ.store coinbase in
      { blockchain_state
      ; consensus_data
      ; sok_digest
      ; supply_increase
      ; ledger_proof
      ; proposer
      ; coinbase }
    in
    let read
        { blockchain_state
        ; consensus_data
        ; sok_digest
        ; supply_increase
        ; ledger_proof
        ; proposer
        ; coinbase } =
      let open Read.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.read blockchain_state
      and consensus_data = Consensus_data.typ.read consensus_data
      and sok_digest = Sok_message.Digest.typ.read sok_digest
      and supply_increase = Currency.Amount.typ.read supply_increase
      and proposer = Signature_lib.Public_key.Compressed.typ.read proposer
      and coinbase = Currency.Amount.typ.read coinbase in
      { blockchain_state
      ; consensus_data
      ; sok_digest
      ; supply_increase
      ; ledger_proof
      ; proposer
      ; coinbase }
    in
    let check
        { blockchain_state
        ; consensus_data
        ; sok_digest
        ; supply_increase
        ; ledger_proof= _
        ; proposer
        ; coinbase } =
      let open Snark_params.Tick in
      let%map () = Blockchain_state.typ.check blockchain_state
      and () = Consensus_data.typ.check consensus_data
      and () = Sok_message.Digest.typ.check sok_digest
      and () = Currency.Amount.typ.check supply_increase
      and () = Signature_lib.Public_key.Compressed.typ.check proposer in
      ()
    in
    let alloc =
      let open Alloc.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.alloc
      and consensus_data = Consensus_data.typ.alloc
      and sok_digest = Sok_message.Digest.typ.alloc
      and supply_increase = Currency.Amount.typ.alloc
      and proposer = Signature_lib.Public_key.Compressed.typ.alloc
      and coinbase = Currency.Amount.typ.alloc in
      { blockchain_state
      ; consensus_data
      ; sok_digest
      ; supply_increase
      ; ledger_proof= None
      ; proposer
      ; coinbase }
    in
    {Snarky.Types.Typ.store; read; check; alloc}

  let genesis =
    { blockchain_state= Blockchain_state.genesis
    ; consensus_data= Consensus_data.genesis
    ; supply_increase= Currency.Amount.zero
    ; sok_digest=
        Sok_message.digest
          { fee= Currency.Fee.zero
          ; prover=
              Account.public_key
                (List.hd_exn (Ledger.to_list Genesis_ledger.t)) }
    ; ledger_proof= None
    ; proposer= Signature_lib.Public_key.Compressed.empty
    ; coinbase= Currency.Amount.zero }
end
