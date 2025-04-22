open Core_kernel

module Helper = struct
  open Mina_base

  let to_yojson ~proof_to_yojson tx =
    User_command.Poly.to_yojson Signed_command.to_yojson
      (Zkapp_command.with_forest_to_yojson proof_to_yojson
         Zkapp_command.Digest.Account_update.to_yojson
         Zkapp_command.Digest.Forest.to_yojson )
      tx

  let of_yojson ~proof_of_yojson =
    User_command.Poly.of_yojson Signed_command.of_yojson
    @@ Zkapp_command.with_forest_of_yojson proof_of_yojson
         Zkapp_command.Digest.Account_update.of_yojson
         Zkapp_command.Digest.Forest.of_yojson
end

module User_command = struct
  open Mina_base

  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = User_command.Stable.V2.t [@@deriving sexp]

      let to_yojson : t -> Yojson.Safe.t =
        let signature_kind = Mina_signature_kind.t_DEPRECATED in
        function
        | User_command.Poly.Signed_command tx ->
            Helper.to_yojson ~proof_to_yojson:Proof.to_yojson (Signed_command tx)
        | User_command.Poly.Zkapp_command { fee_payer; memo; account_updates }
          ->
            Helper.to_yojson ~proof_to_yojson:Proof.to_yojson
              (Zkapp_command
                 { Zkapp_command.Poly.fee_payer
                 ; memo
                 ; account_updates =
                     Zkapp_command.(
                       Call_forest.accumulate_hashes
                         ~hash_account_update:
                           (Digest.Account_update.create ~signature_kind))
                       account_updates
                 } )

      let of_yojson json =
        match Helper.of_yojson ~proof_of_yojson:Proof.of_yojson json with
        | Ok (Signed_command tx) ->
            Ppx_deriving_yojson_runtime.Result.Ok
              (User_command.Poly.Signed_command tx)
        | Ok (Zkapp_command { fee_payer; memo; account_updates }) ->
            Ok
              (Zkapp_command
                 { Zkapp_command.Poly.fee_payer
                 ; memo
                 ; account_updates =
                     Zkapp_command.Call_forest.forget_hashes account_updates
                 } )
        | Error e ->
            Error e

      let to_latest = Fn.id
    end
  end]

  type nonrec t = User_command.t

  let proof_to_yojson = Proof.to_yojson

  let proof_of_yojson = Proof.of_yojson

  let to_yojson = Helper.to_yojson ~proof_to_yojson

  let of_yojson = Helper.of_yojson ~proof_of_yojson
end

module Staged_ledger_diff = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
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

      let to_latest = ident
    end
  end]
end
