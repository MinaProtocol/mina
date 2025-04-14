open Core_kernel
open Mina_base

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = Mina_wire_types.Staged_ledger_diff.V2.t =
      { diff :
          ( Transaction_snark_work.Stable.V2.t
          , Legacy_user_command.Stable.V1.t With_status.Stable.V2.t )
          Staged_ledger_diff.Pre_diff_two.Stable.V2.t
          * ( Transaction_snark_work.Stable.V2.t
            , Legacy_user_command.Stable.V1.t With_status.Stable.V2.t )
            Staged_ledger_diff.Pre_diff_one.Stable.V2.t
            option
      }
    [@@deriving sexp, yojson]

    val to_latest : t -> t
  end
end]
