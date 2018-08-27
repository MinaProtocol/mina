open Core_kernel

module type Consensus_data_intf = sig
  type value [@@deriving bin_io, sexp]

  include Snark_params.Tick.Snarkable.S with type value := value

  val genesis : value
end

module type S = sig
  module Consensus_data : Consensus_data_intf

  type ('blockchain_state, 'consensus_data) t [@@deriving sexp]

  type value = (Blockchain_state.value, Consensus_data.value) t
  [@@deriving bin_io, sexp]

  type var = (Blockchain_state.var, Consensus_data.var) t

  include Snark_params.Tick.Snarkable.S
          with type value := value
           and type var := var

  val create_value :
       blockchain_state:Blockchain_state.value
    -> consensus_data:Consensus_data.value
    -> ledger_proof:Proof.t option
    -> value

  val blockchain_state : ('a, _) t -> 'a

  val consensus_data : (_, 'a) t -> 'a

  val ledger_proof : _ t -> Proof.t option

  val genesis : value
end

module Make (Consensus_data : Consensus_data_intf) :
  S with module Consensus_data = Consensus_data =
struct
  module Consensus_data = Consensus_data

  type ('blockchain_state, 'consensus_data) t =
    { blockchain_state: 'blockchain_state
    ; consensus_data: 'consensus_data
    ; ledger_proof: Proof.t option }
  [@@deriving bin_io, sexp, fields]

  type value = (Blockchain_state.value, Consensus_data.value) t
  [@@deriving bin_io, sexp]

  type var = (Blockchain_state.var, Consensus_data.var) t

  let create_value ~blockchain_state ~consensus_data ~ledger_proof =
    {blockchain_state; consensus_data; ledger_proof}

  let to_hlist {blockchain_state; consensus_data; ledger_proof= _} =
    H_list.[blockchain_state; consensus_data]

  let of_hlist : (unit, 'ps -> 'cd -> unit) H_list.t -> ('ps, 'cd) t =
   fun H_list.([blockchain_state; consensus_data]) ->
    {blockchain_state; consensus_data; ledger_proof= None}

  let data_spec =
    Snark_params.Tick.Data_spec.[Blockchain_state.typ; Consensus_data.typ]

  let typ =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let genesis =
    { blockchain_state= Blockchain_state.genesis
    ; consensus_data= Consensus_data.genesis
    ; ledger_proof= None }
end
