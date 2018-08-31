open Core_kernel

module type Consensus_data_intf = sig
  type value [@@deriving bin_io, sexp]

  include Snark_params.Tick.Snarkable.S with type value := value

  val genesis : value
end

module type S = sig
  module Consensus_data : Consensus_data_intf

  type ('blockchain_state, 'consensus_data, 'fee_excess) t [@@deriving sexp]

  type value = (Blockchain_state.value, Consensus_data.value, Currency.Fee.Signed.t) t
  [@@deriving bin_io, sexp]

  type var = (Blockchain_state.var, Consensus_data.var, Currency.Fee.Signed.var) t

  include Snark_params.Tick.Snarkable.S
          with type value := value
           and type var := var

  val create_value :
       blockchain_state:Blockchain_state.value
    -> consensus_data:Consensus_data.value
    -> ledger_proof:Proof.t option
    -> fee_excess: Currency.Fee.Signed.t
    -> value

  val blockchain_state : ('a, _, _) t -> 'a

  val consensus_data : (_, 'a, _) t -> 'a

  val ledger_proof : _ t -> Proof.t option
  
  val fee_excess : (_, _, 'a) t -> 'a

  val genesis : value
end

module Make (Consensus_data : Consensus_data_intf) :
  S with module Consensus_data = Consensus_data =
struct
  module Consensus_data = Consensus_data

  type ('blockchain_state, 'consensus_data, 'fee_excess) t =
    { blockchain_state: 'blockchain_state
    ; consensus_data: 'consensus_data
    ; ledger_proof : Proof.t option 
    ; fee_excess: 'fee_excess }
  [@@deriving bin_io, sexp, fields]

  type value = (Blockchain_state.value, Consensus_data.value, Currency.Fee.Signed.t) t
  [@@deriving bin_io, sexp]

  type var = (Blockchain_state.var, Consensus_data.var, Currency.Fee.Signed.var) t

  let create_value ~blockchain_state ~consensus_data ~ledger_proof ~fee_excess =
    {blockchain_state; consensus_data; ledger_proof; fee_excess}

  let to_hlist {blockchain_state; consensus_data; fee_excess; _} =
    H_list.[blockchain_state; consensus_data; fee_excess]

  let of_hlist : (unit, 'ps -> 'cd -> 'fe -> unit) H_list.t -> ('ps, 'cd, 'fe) t =
   fun H_list.([blockchain_state; consensus_data; fee_excess]) ->
    {blockchain_state; consensus_data; ledger_proof = None; fee_excess}

  let data_spec =
    Snark_params.Tick.Data_spec.[Blockchain_state.typ; Consensus_data.typ; Currency.Fee.Signed.typ]

  let typ =
    Snark_params.Tick.Typ.of_hlistable data_spec ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let genesis =
    { blockchain_state= Blockchain_state.genesis
    ; consensus_data= Consensus_data.genesis
    ; ledger_proof = None
    ; fee_excess= Currency.Fee.Signed.zero }
end
