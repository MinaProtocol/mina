open Core_kernel

module type Consensus_data_intf = sig
  type value [@@deriving bin_io, sexp]

  include Snark_params.Tick.Snarkable.S with type value := value

  val genesis : value
end

module type S = sig
  module Consensus_data : Consensus_data_intf

  module Proof : sig
    type t [@@deriving bin_io, sexp]
  end

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

module Make
    (Consensus_data : Consensus_data_intf) (Proof : sig
        type t [@@deriving bin_io, sexp]
    end) :
  S with module Consensus_data = Consensus_data and module Proof = Proof =
struct
  module Consensus_data = Consensus_data
  module Proof = Proof

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

  let to_hlist {blockchain_state; consensus_data; sok_digest; ledger_proof= _} =
    H_list.[blockchain_state; consensus_data; sok_digest]

  let of_hlist :
      (unit, 'ps -> 'cd -> 'dig -> unit) H_list.t -> ('ps, 'cd, 'dig) t =
   fun H_list.([blockchain_state; consensus_data; sok_digest]) ->
    {blockchain_state; consensus_data; sok_digest; ledger_proof= None}

  let data_spec =
    let open Snark_params.Tick.Data_spec in
    [Blockchain_state.typ; Consensus_data.typ; Sok_message.Digest.typ]

  let typ =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let genesis =
    { blockchain_state= Blockchain_state.genesis
    ; consensus_data= Consensus_data.genesis
    ; sok_digest=
        Sok_message.digest
          {fee= Currency.Fee.zero; prover= Genesis_ledger.high_balance_pk}
    ; ledger_proof= None }
end
