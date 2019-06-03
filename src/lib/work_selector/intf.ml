module type S = sig
  type snark_pool

  type fee

  type staged_ledger

  type work

  module State : sig
    type t

    val init : t
  end

  val work :
       snark_pool:snark_pool
    -> fee:fee
    -> staged_ledger
    -> State.t
    -> work list * State.t
end
