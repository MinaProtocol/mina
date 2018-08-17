open Core_kernel
open Async_kernel
open Nanobit_base

module Make_prod (Init : sig
  val logger : Logger.t

  val verifier : Verifier.t
end) =
struct
  type t = Transaction_snark.t [@@deriving bin_io, sexp]

  let statement = Transaction_snark.statement

  let proof = Transaction_snark.proof

  (* TODO: Use the message once SOK is implemented *)
  let verify t stmt ~message:_ =
    if
      not
        (Int.( = )
           (Transaction_snark.Statement.compare
              (Transaction_snark.statement t)
              stmt)
           0)
    then Deferred.return false
    else
      match%map Verifier.verify_transaction_snark Init.verifier t with
      | Ok b -> b
      | Error e ->
          Logger.warn Init.logger !"Bad transaction snark: %{sexp: Error.t}" e ;
          false
end

module Debug = struct
  type t = Transaction_snark.Statement.t [@@deriving sexp, bin_io]

  let proof _ = Proof.dummy

  let statement = ident

  let verify _ _ ~message:_ = return true
end
