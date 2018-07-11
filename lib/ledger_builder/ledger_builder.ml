open Core_kernel
open Async_kernel
open Protocols

module type Inputs_intf = sig
  module Fee : sig
    module Unsigned : sig
      type t [@@deriving sexp_of, eq]

      val add : t -> t -> t option

      val sub : t -> t -> t option

      val zero : t
    end

    module Signed : sig
      type t [@@deriving sexp_of]

      val add : t -> t -> t option

      val negate : t -> t

      val of_unsigned : Unsigned.t -> t
    end
  end

  module Public_key : sig
    type t
  end

  module Transaction :
    Coda_pow.Transaction_intf with type fee := Fee.Unsigned.t

  module Fee_transfer :
    Coda_pow.Fee_transfer_intf
    with type public_key := Public_key.t
     and type fee := Fee.Unsigned.t

  module Super_transaction :
    Coda_pow.Super_transaction_intf
    with type valid_transaction := Transaction.With_valid_signature.t
     and type fee_transfer := Fee_transfer.t
     and type unsigned_fee := Fee.Unsigned.t

  module Ledger_hash : Coda_pow.Ledger_hash_intf

  module Transaction_snark :
    Coda_pow.Transaction_snark_intf
    with type message := Fee.Unsigned.t * Public_key.t
     and type fee_excess := Fee.Signed.t
     and type ledger_hash := Ledger_hash.t

  module Ledger :
    Coda_pow.Ledger_intf
    with type ledger_hash := Ledger_hash.t
     and type super_transaction := Super_transaction.t
     and type valid_transaction := Transaction.With_valid_signature.t

  module Ledger_builder_hash : Coda_pow.Ledger_builder_hash_intf

  module Completed_work :
    Coda_pow.Completed_work_intf
    with type proof := Transaction_snark.t
     and type statement := Transaction_snark.Statement.t
     and type fee := Fee.Unsigned.t
     and type public_key := Public_key.t

  module Ledger_builder_diff :
    Coda_pow.Ledger_builder_diff_intf
    with type completed_work := Completed_work.t
     and type transaction := Transaction.With_valid_signature.t
     and type public_key := Public_key.t
     and type ledger_builder_hash := Ledger_builder_hash.t
end

module Make (Inputs : Inputs_intf) :
  Coda_pow.Ledger_builder_intf
  with type diff := Inputs.Ledger_builder_diff.t
   and type ledger_builder_hash := Inputs.Ledger_builder_hash.t
   and type public_key := Inputs.Public_key.t
   and type ledger := Inputs.Ledger.t
   and type ledger_proof := Inputs.Transaction_snark.t
   and type transaction_with_valid_signature :=
              Inputs.Transaction.With_valid_signature.t
   and type statement := Inputs.Completed_work.Statement.t
   and type completed_work := Inputs.Completed_work.t =
struct
  type t = unit [@@deriving sexp, bin_io]

  let ledger = failwith "TODO"

  let margin = failwith "TODO"

  let copy = failwith "TODO"

  let max_margin = failwith "TODO"

  let hash = failwith "TODO"

  let create = failwith "TODO"

  let apply = failwith "TODO"

  let create_diff = failwith "TODO"
end
