open Core
open Protocols

type t =
  | Transaction of Transaction.With_valid_signature.t
  | Fee_transfer of Fee_transfer.t
[@@deriving bin_io, sexp]
