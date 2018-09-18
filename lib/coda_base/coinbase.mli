open Core
open Import

type t = private
  {proposer: Public_key.Compressed.t; fee_transfer: Fee_transfer.single option}
[@@deriving sexp, bin_io, compare, eq]

val create :
     proposer:Public_key.Compressed.t
  -> fee_transfer:Fee_transfer.single option
  -> t Or_error.t

val supply_increase : t -> Currency.Amount.t Or_error.t

val fee_excess : t -> Currency.Fee.Signed.t Or_error.t
