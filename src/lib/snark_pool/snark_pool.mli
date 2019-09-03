open Core_kernel
open Coda_base
open Pipe_lib

module Priced_proof : sig
  module Stable : sig
    module V1 : sig
      type 'proof t = {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
      [@@deriving bin_io, sexp, fields, yojson, version]
    end

    module Latest = V1
  end

  type 'proof t = 'proof Stable.Latest.t =
    {proof: 'proof; fee: Fee_with_prover.Stable.V1.t}
end

module type Transition_frontier_intf = sig
  type 'a transaction_snark_work_statement_table

  type t

  val snark_pool_refcount_pipe :
       t
    -> (int * int transaction_snark_work_statement_table)
       Pipe_lib.Broadcast_pipe.Reader.t
end

module type S = sig
  type ledger_proof

  type work

  type transition_frontier

  type t [@@deriving bin_io]

  val create :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> frontier_broadcast_pipe:transition_frontier Option.t
                               Broadcast_pipe.Reader.t
    -> t

  val add_snark :
       t
    -> work:work
    -> proof:ledger_proof list
    -> fee:Fee_with_prover.t
    -> [`Rebroadcast | `Don't_rebroadcast]

  val request_proof : t -> work -> ledger_proof list Priced_proof.t option

  val listen_to_frontier_broadcast_pipe :
    transition_frontier option Broadcast_pipe.Reader.t -> t -> unit
end

module Make (Ledger_proof : sig
  type t [@@deriving bin_io, sexp, version]
end) (Work : sig
  type t [@@deriving sexp]

  module Stable :
    sig
      module V1 : sig
        type t [@@deriving sexp, bin_io]

        include Hashable.S_binable with type t := t
      end
    end
    with type V1.t = t

  include Hashable.S with type t := t
end)
(Transition_frontier : Transition_frontier_intf with type 'a transaction_snark_work_statement_table := 'a Work.Table.t) :
  S
  with type work := Work.t
   and type transition_frontier := Transition_frontier.t
   and type ledger_proof := Ledger_proof.t

include
  S
  with type work := Transaction_snark_work.Statement.t
   and type transition_frontier := Transition_frontier.t
   and type ledger_proof := Ledger_proof.t
