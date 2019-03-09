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
       , 'supply_increase
       , 'pending_coinbase_state ) t
  [@@deriving sexp]

  type value =
    ( Blockchain_state.value
    , Consensus_data.value
    , Sok_message.Digest.t
    , Currency.Amount.t
    , Pending_coinbase_update.value )
    t
  [@@deriving bin_io, sexp]

  type var =
    ( Blockchain_state.var
    , Consensus_data.var
    , Sok_message.Digest.Checked.t
    , Currency.Amount.var
    , Pending_coinbase_update.var )
    t

  include
    Snark_params.Tick.Snarkable.S with type value := value and type var := var

  val create_value :
       ?sok_digest:Sok_message.Digest.t
    -> ?ledger_proof:Proof.t
    -> supply_increase:Currency.Amount.t
    -> blockchain_state:Blockchain_state.value
    -> consensus_data:Consensus_data.value
    -> pending_coinbase_update:Pending_coinbase_update.value
    -> unit
    -> value

  val blockchain_state : ('a, _, _, _, _) t -> 'a

  val consensus_data : (_, 'a, _, _, _) t -> 'a

  val sok_digest : (_, _, 'a, _, _) t -> 'a

  val supply_increase : (_, _, _, 'a, _) t -> 'a

  val ledger_proof : _ t -> Proof.t option

  val pending_coinbase_update : (_, _, _, _, 'a) t -> 'a

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
       , 'supply_increase
       , 'pending_coinbase_state ) t =
    { blockchain_state: 'blockchain_state
    ; consensus_data: 'consensus_data
    ; sok_digest: 'sok_digest
    ; supply_increase: 'supply_increase
    ; ledger_proof: Proof.t option
    ; pending_coinbase_update: 'pending_coinbase_state }
  [@@deriving bin_io, sexp, fields]

  type value =
    ( Blockchain_state.value
    , Consensus_data.value
    , Sok_message.Digest.Stable.V1.t
    , Currency.Amount.t
    , Pending_coinbase_update.value )
    t
  [@@deriving bin_io, sexp]

  type var =
    ( Blockchain_state.var
    , Consensus_data.var
    , Sok_message.Digest.Checked.t
    , Currency.Amount.var
    , Pending_coinbase_update.var )
    t

  let create_value ?(sok_digest = Sok_message.Digest.default) ?ledger_proof
      ~supply_increase ~blockchain_state ~consensus_data
      ~pending_coinbase_update () =
    { blockchain_state
    ; consensus_data
    ; ledger_proof
    ; sok_digest
    ; supply_increase
    ; pending_coinbase_update }

  let typ =
    let open Snark_params.Tick.Typ in
    let store
        { blockchain_state
        ; consensus_data
        ; sok_digest
        ; supply_increase
        ; ledger_proof
        ; pending_coinbase_update } =
      let open Store.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.store blockchain_state
      and consensus_data = Consensus_data.typ.store consensus_data
      and sok_digest = Sok_message.Digest.typ.store sok_digest
      and supply_increase = Currency.Amount.typ.store supply_increase
      and pending_coinbase_update =
        Pending_coinbase_update.typ.store pending_coinbase_update
      in
      { blockchain_state
      ; consensus_data
      ; sok_digest
      ; supply_increase
      ; ledger_proof
      ; pending_coinbase_update }
    in
    let read
        { blockchain_state
        ; consensus_data
        ; sok_digest
        ; supply_increase
        ; ledger_proof
        ; pending_coinbase_update } =
      let open Read.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.read blockchain_state
      and consensus_data = Consensus_data.typ.read consensus_data
      and sok_digest = Sok_message.Digest.typ.read sok_digest
      and supply_increase = Currency.Amount.typ.read supply_increase
      and pending_coinbase_update =
        Pending_coinbase_update.typ.read pending_coinbase_update
      in
      { blockchain_state
      ; consensus_data
      ; sok_digest
      ; supply_increase
      ; ledger_proof
      ; pending_coinbase_update }
    in
    let check
        { blockchain_state
        ; consensus_data
        ; sok_digest
        ; supply_increase
        ; ledger_proof= _
        ; pending_coinbase_update } =
      let open Snark_params.Tick.Let_syntax in
      let%map () = Blockchain_state.typ.check blockchain_state
      and () = Consensus_data.typ.check consensus_data
      and () = Sok_message.Digest.typ.check sok_digest
      and () = Currency.Amount.typ.check supply_increase
      and () = Pending_coinbase_update.typ.check pending_coinbase_update in
      ()
    in
    let alloc =
      let open Alloc.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.alloc
      and consensus_data = Consensus_data.typ.alloc
      and sok_digest = Sok_message.Digest.typ.alloc
      and supply_increase = Currency.Amount.typ.alloc
      and pending_coinbase_update = Pending_coinbase_update.typ.alloc in
      { blockchain_state
      ; consensus_data
      ; sok_digest
      ; supply_increase
      ; ledger_proof= None
      ; pending_coinbase_update }
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
    ; pending_coinbase_update= Pending_coinbase_update.genesis }
end
