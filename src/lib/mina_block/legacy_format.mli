open Core_kernel

module User_command : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t = Mina_base.User_command.Stable.V2.t [@@deriving sexp, yojson]

      val to_latest : t -> t
    end
  end]

  type t = Mina_base.User_command.t [@@deriving yojson]
end

module Staged_ledger_diff : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t = Mina_wire_types.Staged_ledger_diff.V2.t =
        { diff :
            ( Transaction_snark_work.Stable.V2.t
            , User_command.Stable.V1.t Mina_base.With_status.Stable.V2.t )
            Staged_ledger_diff.Pre_diff_two.Stable.V2.t
            * ( Transaction_snark_work.Stable.V2.t
              , User_command.Stable.V1.t Mina_base.With_status.Stable.V2.t )
              Staged_ledger_diff.Pre_diff_one.Stable.V2.t
              option
        }
      [@@deriving sexp, yojson]

      val to_latest : t -> t
    end
  end]
end
