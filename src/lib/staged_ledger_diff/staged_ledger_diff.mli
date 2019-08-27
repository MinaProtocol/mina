module Make (Transaction_snark_work : sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving bin_io, sexp, to_yojson, version]
    end
  end

  type t = Stable.V1.t [@@deriving to_yojson]

  module Checked : sig
    type t [@@deriving sexp, to_yojson]
  end

  val forget : Checked.t -> t
end) :
  Coda_intf.Staged_ledger_diff_intf
  with type transaction_snark_work := Transaction_snark_work.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t

include
  Coda_intf.Staged_ledger_diff_intf
  with type transaction_snark_work := Transaction_snark_work.t
   and type transaction_snark_work_checked := Transaction_snark_work.Checked.t
