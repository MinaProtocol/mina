open Core_kernel
open Async_kernel
open Nanobit_base

module Make_prod (Init : sig
  val logger : Logger.t

  val verifier : Verifier.t
end) =
struct
  include Proof.Stable.V1

  let verify t state =
    let open Deferred.Let_syntax in
    let state = State.to_blockchain_state state in
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
