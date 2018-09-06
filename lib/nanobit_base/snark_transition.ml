open Core_kernel

module type Consensus_data_intf = sig
  type value [@@deriving bin_io, sexp]

  include Snark_params.Tick.Snarkable.S with type value := value

  val genesis : value
end

module type S = sig
  module Consensus_data : Consensus_data_intf

  type ('blockchain_state, 'consensus_data, 'sok_digest) t [@@deriving sexp]

  type value =
    (Blockchain_state.value, Consensus_data.value, Sok_message.Digest.t) t
  [@@deriving bin_io, sexp]

  type var =
    (Blockchain_state.var, Consensus_data.var, Sok_message.Digest.Checked.t) t

  include Snark_params.Tick.Snarkable.S
          with type value := value
           and type var := var

  val create_value :
       ?sok_digest:Sok_message.Digest.t
    -> ?ledger_proof:Proof.t
    -> blockchain_state:Blockchain_state.value
    -> consensus_data:Consensus_data.value
    -> unit
    -> value

  val blockchain_state : ('a, _, _) t -> 'a

  val consensus_data : (_, 'a, _) t -> 'a

  val sok_digest : (_, _, 'a) t -> 'a

  val ledger_proof : _ t -> Proof.t option

  val genesis : value
end

module Make (Consensus_data : Consensus_data_intf) :
  S with module Consensus_data = Consensus_data =
struct
  module Consensus_data = Consensus_data

  type ('blockchain_state, 'consensus_data, 'sok_digest) t =
    { blockchain_state: 'blockchain_state
    ; consensus_data: 'consensus_data
    ; sok_digest: 'sok_digest
    ; ledger_proof: Proof.t option }
  [@@deriving bin_io, sexp, fields]

  type value =
    ( Blockchain_state.value
    , Consensus_data.value
    , Sok_message.Digest.Stable.V1.t )
    t
  [@@deriving bin_io, sexp]

  type var =
    (Blockchain_state.var, Consensus_data.var, Sok_message.Digest.Checked.t) t

  let create_value ?(sok_digest= Sok_message.Digest.default) ?ledger_proof
      ~blockchain_state ~consensus_data () =
    {blockchain_state; consensus_data; ledger_proof; sok_digest}

  let typ =
    let open Snark_params.Tick.Typ in
    let store {blockchain_state; consensus_data; sok_digest; ledger_proof} =
      let open Store.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.store blockchain_state
      and consensus_data = Consensus_data.typ.store consensus_data
      and sok_digest = Sok_message.Digest.typ.store sok_digest in
      {blockchain_state; consensus_data; sok_digest; ledger_proof}
    in
    let read {blockchain_state; consensus_data; sok_digest; ledger_proof} =
      let open Read.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.read blockchain_state
      and consensus_data = Consensus_data.typ.read consensus_data
      and sok_digest = Sok_message.Digest.typ.read sok_digest in
      {blockchain_state; consensus_data; sok_digest; ledger_proof}
    in
    let check {blockchain_state; consensus_data; sok_digest; ledger_proof= _} =
      let open Snark_params.Tick.Let_syntax in
      let%map () = Blockchain_state.typ.check blockchain_state
      and () = Consensus_data.typ.check consensus_data
      and () = Sok_message.Digest.typ.check sok_digest in
      ()
    in
    let alloc =
      let open Alloc.Let_syntax in
      let%map blockchain_state = Blockchain_state.typ.alloc
      and consensus_data = Consensus_data.typ.alloc
      and sok_digest = Sok_message.Digest.typ.alloc in
      {blockchain_state; consensus_data; sok_digest; ledger_proof= None}
    in
    {store; read; check; alloc}

  let genesis =
    { blockchain_state= Blockchain_state.genesis
    ; consensus_data= Consensus_data.genesis
    ; sok_digest=
        Sok_message.digest
          {fee= Currency.Fee.zero; prover= Genesis_ledger.high_balance_pk}
    ; ledger_proof= None }
end
