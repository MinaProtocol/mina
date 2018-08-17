open Core_kernel

module type Consensus_data_intf = sig
  include Snark_params.Tick.Snarkable.S

  val genesis : value
end

module type S = sig
  module Consensus_data : Consensus_data_intf

  module Protocol_state : Protocol_state.S

  module Proof : sig
    type t [@@deriving bin_io, sexp]
  end

  type ('protocol_state, 'consensus_data) t [@@deriving sexp]

  type value = (Protocol_state.value, Consensus_data.value) t [@@deriving sexp]

  type var = (Protocol_state.var, Consensus_data.var) t

  include Snark_params.Tick.Snarkable.S
          with type value := value
           and type var := var

  val create_value :
       protocol_state:Protocol_state.value
    -> consensus_data:Consensus_data.value
    -> ledger_proof:Proof.t option
    -> value

  val protocol_state : ('a, _) t -> 'a

  val consensus_data : (_, 'a) t -> 'a

  val ledger_proof : _ t -> Proof.t option

  val genesis : value
end

module Make
    (Consensus_data : Consensus_data_intf)
    (Protocol_state : Protocol_state.S) (Proof : sig
        type t [@@deriving bin_io, sexp]
    end) :
  S
  with module Protocol_state = Protocol_state
   and module Consensus_data = Consensus_data
   and module Proof = Proof =
struct
  module Consensus_data = Consensus_data
  module Protocol_state = Protocol_state
  module Proof = Proof

  type ('protocol_state, 'consensus_data) t =
    { protocol_state: 'protocol_state
    ; consensus_data: 'consensus_data
    ; ledger_proof: Proof.t option }
  [@@deriving bin_io, sexp, fields]

  type value = (Protocol_state.value, Consensus_data.value) t
  [@@deriving bin_io, sexp]

  type var = (Protocol_state.var, Consensus_data.var) t

  let create_value ~protocol_state ~consensus_data ~ledger_proof =
    {protocol_state; consensus_data; ledger_proof}

  let to_hlist {protocol_state; consensus_data; ledger_proof= _} =
    H_list.[protocol_state; consensus_data]

  let of_hlist : (unit, 'ps -> 'cd -> unit) H_list.t -> ('ps, 'cd) t =
   fun H_list.([protocol_state; consensus_data]) ->
    {protocol_state; consensus_data; ledger_proof= None}

  let data_spec =
    Snark_params.Tick.Data_spec.[Protocol_state.typ; Consensus_data.typ]

  let typ =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let genesis =
    { protocol_state= Protocol_state.negative_one
    ; consensus_data= Consensus_data.genesis
    ; ledger_proof= None }
end
