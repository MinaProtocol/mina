open Core_kernel
open Mina_base

module User_command : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t =
        ( Signed_command.Stable.V2.t
        , ( Account_update.Stable.V1.t
          , Zkapp_command.Digest.Account_update.Stable.V1.t
          , Zkapp_command.Digest.Forest.Stable.V1.t )
          Zkapp_command.Call_forest.Stable.V1.t
          Zkapp_command.Poly.Stable.V1.t )
        User_command.Poly.Stable.V2.t
      [@@deriving sexp, yojson]

      val to_latest : t -> t
    end
  end]

  val to_stable_user_command : t -> User_command.Stable.Latest.t
end

module Staged_ledger_diff : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t =
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

  val to_stable_staged_ledger_diff :
    Stable.Latest.t -> Staged_ledger_diff.Stable.Latest.t

  val of_stable_staged_ledger_diff :
       signature_kind:Mina_signature_kind.t
    -> Staged_ledger_diff.Stable.Latest.t
    -> Stable.Latest.t
end
