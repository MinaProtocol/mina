open Core_kernel

module Common = struct
  let to_yojson tx =
    User_command.Poly.to_yojson Signed_command.to_yojson
      (Zkapp_command.with_forest_to_yojson
         Zkapp_command.Digest.Account_update.to_yojson
         Zkapp_command.Digest.Forest.to_yojson )
      tx

  let of_yojson =
    User_command.Poly.of_yojson Signed_command.of_yojson
    @@ Zkapp_command.with_forest_of_yojson
         Zkapp_command.Digest.Account_update.of_yojson
         Zkapp_command.Digest.Forest.of_yojson
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V1 = struct
    type t = User_command.Stable.V2.t [@@deriving sexp]

    let to_yojson : t -> Yojson.Safe.t = function
      | User_command.Poly.Signed_command tx ->
          Common.to_yojson (Signed_command tx)
      | User_command.Poly.Zkapp_command { fee_payer; memo; account_updates } ->
          Common.to_yojson
            (Zkapp_command
               { Zkapp_command.Poly.fee_payer
               ; memo
               ; account_updates (* TODO accumulate hashes *)
               } )

    let of_yojson json =
      match Common.of_yojson json with
      | Ok (Signed_command tx) ->
          Ppx_deriving_yojson_runtime.Result.Ok
            (User_command.Poly.Signed_command tx)
      | Ok (Zkapp_command { fee_payer; memo; account_updates }) ->
          Ok
            (Zkapp_command
               { Zkapp_command.Poly.fee_payer
               ; memo
               ; account_updates (* TODO forget hashes *)
               } )
      | Error e ->
          Error e

    let to_latest = Fn.id
  end
end]

type nonrec t = User_command.t

let to_yojson = Common.to_yojson

let of_yojson = Common.of_yojson
