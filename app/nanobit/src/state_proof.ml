open Core_kernel
open Async_kernel
open Nanobit_base

module Make_prod (Init : sig
  val prover : Prover.t
end) =
struct
  type input = State.t

  type t = Proof.Stable.V1.t [@@deriving bin_io]

  let verify proof s =
    Prover.verify_blockchain Init.prover
      {Blockchain_snark.Blockchain.state= State.to_blockchain_state s; proof}
    >>| Or_error.ok_exn
end

module Make_debug (Init : sig
  type proof [@@deriving bin_io]
end) =
struct
  type input = State.t

  type t = Init.proof [@@deriving bin_io]

  let verify _ _ = return true
end
