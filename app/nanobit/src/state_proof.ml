open Core_kernel
open Async_kernel
open Coda_base

module Make_prod
    (Consensus_mechanism : Consensus.Mechanism.S)
    (Protocol_state : Protocol_state.S
                      with module Consensus_mechanism := Consensus_mechanism)
    (Blockchain : Blockchain_snark.Blockchain.S
                  with module Consensus_mechanism = Consensus_mechanism
                   and module Protocol_state = Protocol_state)
    (Verifier : Verifier.S with type blockchain := Blockchain.t) (Init : sig
        val logger : Logger.t

        val verifier : Verifier.t
    end) =
struct
  include Proof.Stable.V1

  let verify t state =
    let open Deferred.Let_syntax in
    match%map Verifier.verify_blockchain Init.verifier {proof= t; state} with
    | Ok b -> b
    | Error e ->
        Logger.warn Init.logger !"Bad blockchain snark: %{sexp: Error.t}" e ;
        false
end

module Make_debug (Init : sig
  type t [@@deriving bin_io, sexp]
end) =
struct
  include Init

  let verify _ _ = return true
end
