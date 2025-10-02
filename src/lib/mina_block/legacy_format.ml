open Core_kernel

module User_command = struct
  open Mina_base

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Signed_command.Stable.V2.t
        , ( Account_update.Stable.V1.t
          , Zkapp_command.Digest.Account_update.Stable.V1.t
          , Zkapp_command.Digest.Forest.Stable.V1.t )
          Zkapp_command.Call_forest.Stable.V1.t
          Zkapp_command.Poly.Stable.V1.t )
        User_command.Poly.Stable.V2.t
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end
  end]

  let of_stable_user_command ~signature_kind = function
    | User_command.Poly.Signed_command _ as tx ->
        (tx : t)
    | Zkapp_command { Zkapp_command.Poly.fee_payer; memo; account_updates } ->
        User_command.Poly.Zkapp_command
          { Zkapp_command.Poly.fee_payer
          ; memo
          ; account_updates =
              Zkapp_command.(
                Call_forest.accumulate_hashes
                  ~hash_account_update:
                    (Digest.Account_update.create ~signature_kind))
                account_updates
          }

  let to_stable_user_command = function
    | (Signed_command _ as tx : t) ->
        tx
    | (Zkapp_command { fee_payer; memo; account_updates } : t) ->
        Zkapp_command
          { Zkapp_command.Poly.fee_payer
          ; memo
          ; account_updates =
              Zkapp_command.Call_forest.forget_hashes account_updates
          }
end

module Staged_ledger_diff = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
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

      let to_latest = ident
    end
  end]

  let to_stable_staged_ledger_diff { Stable.Latest.diff = ptwo, pone_opt } =
    let f2 = Mina_base.With_status.map ~f:User_command.to_stable_user_command in
    { Staged_ledger_diff.Stable.Latest.diff =
        ( Staged_ledger_diff.Pre_diff_two.map ~f1:ident ~f2 ptwo
        , Option.map
            ~f:(Staged_ledger_diff.Pre_diff_one.map ~f1:ident ~f2)
            pone_opt )
    }

  let of_stable_staged_ledger_diff ~signature_kind
      { Staged_ledger_diff.Stable.Latest.diff = ptwo, pone_opt } =
    let f2 =
      Mina_base.With_status.map
        ~f:(User_command.of_stable_user_command ~signature_kind)
    in
    { Stable.Latest.diff =
        ( Staged_ledger_diff.Pre_diff_two.map ~f1:ident ~f2 ptwo
        , Option.map
            ~f:(Staged_ledger_diff.Pre_diff_one.map ~f1:ident ~f2)
            pone_opt )
    }
end
