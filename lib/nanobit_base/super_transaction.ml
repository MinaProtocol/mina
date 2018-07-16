open Core
open Protocols

type transaction = Transaction.With_valid_signature.t [@@deriving bin_io, sexp]

type fee_transfer = Fee_transfer.t [@@deriving bin_io, sexp]

type t =
  | Transaction of transaction
  | Fee_transfer of Fee_transfer.t
[@@deriving bin_io, sexp]

let super_transaction (txn: transaction) = Transaction txn

let super_transactions (fee: fee_transfer) = Fee_transfer fee
