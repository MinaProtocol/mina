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

  (* TODO: Use the message once SOK is implemented *)
  let verify t stmt ~message:_ =
    if not (Int.(=) (Transaction_snark.Statement.compare (Transaction_snark.statement t) stmt) 0)
    then Deferred.return false
    else
      match%map Verifier.verify_transaction_snark Init.verifier t with
      | Ok b -> b
      | Error e ->
        Logger.warn Init.logger !"Bad transaction snark: %{sexp: Error.t}" e;
        false
end

module Debug = struct
  type t = unit [@@deriving sexp, bin_io]

  let statement _ =
    Quickcheck.Generator.generate ~size:0
      Transaction_snark.Statement.gen
      (Splittable_random.State.of_int 0)

  let verify _ _ ~message:_ = return true
end
