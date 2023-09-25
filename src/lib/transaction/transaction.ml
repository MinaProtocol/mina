open Core_kernel
open Mina_base

module Poly = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type 'command t = 'command Mina_wire_types.Mina_transaction.Poly.V2.t =
        | Command of 'command
        | Fee_transfer of Fee_transfer.Stable.V2.t
        | Coinbase of Coinbase.Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id

      let map t ~f =
        match t with
        | Command x ->
            Command (f x)
        | Fee_transfer x ->
            Fee_transfer x
        | Coinbase x ->
            Coinbase x
    end
  end]
end

module Valid = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = User_command.Valid.Stable.V2.t Poly.Stable.V2.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  include Hashable.Make (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t = User_command.Stable.V2.t Poly.Stable.V2.t
    [@@deriving sexp, compare, equal, hash, yojson]

    let to_latest = Fn.id
  end
end]

include Hashable.Make (Stable.Latest)
include Comparable.Make (Stable.Latest)

type 'command t_ = 'command Poly.t =
  | Command of 'command
  | Fee_transfer of Fee_transfer.t
  | Coinbase of Coinbase.t

let to_valid_unsafe :
    t -> [ `If_this_is_used_it_should_have_a_comment_justifying_it of Valid.t ]
    = function
  | Command t ->
      let (`If_this_is_used_it_should_have_a_comment_justifying_it t') =
        User_command.to_valid_unsafe t
      in
      `If_this_is_used_it_should_have_a_comment_justifying_it (Command t')
  | Fee_transfer t ->
      `If_this_is_used_it_should_have_a_comment_justifying_it (Fee_transfer t)
  | Coinbase t ->
      `If_this_is_used_it_should_have_a_comment_justifying_it (Coinbase t)

let forget : Valid.t -> t = function
  | Command t ->
      Command (User_command.forget_check t)
  | Fee_transfer t ->
      Fee_transfer t
  | Coinbase t ->
      Coinbase t

let fee_excess : t -> Fee_excess.t Or_error.t = function
  | Command (Signed_command t) ->
      Ok (Signed_command.fee_excess t)
  | Command (Zkapp_command ps) ->
      Ok (Zkapp_command.fee_excess ps)
  | Fee_transfer t ->
      Fee_transfer.fee_excess t
  | Coinbase t ->
      Coinbase.fee_excess t

let expected_supply_increase = function
  | Command _ | Fee_transfer _ ->
      Ok Currency.Amount.zero
  | Coinbase t ->
      Coinbase.expected_supply_increase t

let public_keys (t : t) =
  let account_ids =
    match t with
    | Command (Signed_command cmd) ->
        Signed_command.accounts_referenced cmd
    | Command (Zkapp_command t) ->
        Zkapp_command.accounts_referenced t
    | Fee_transfer ft ->
        Fee_transfer.receivers ft
    | Coinbase cb ->
        Coinbase.accounts_referenced cb
  in
  List.map account_ids ~f:Account_id.public_key

let account_access_statuses (t : t) (status : Transaction_status.t) =
  match t with
  | Command (Signed_command cmd) ->
      Signed_command.account_access_statuses cmd status
  | Command (Zkapp_command t) ->
      Zkapp_command.account_access_statuses t status
  | Fee_transfer ft ->
      assert (Transaction_status.equal Applied status) ;
      List.map (Fee_transfer.receivers ft) ~f:(fun acct_id ->
          (acct_id, `Accessed) )
  | Coinbase cb ->
      Coinbase.account_access_statuses cb status

let accounts_referenced (t : t) =
  List.map (account_access_statuses t Applied) ~f:(fun (acct_id, _status) ->
      acct_id )

let fee_payer_pk (t : t) =
  match t with
  | Command (Signed_command cmd) ->
      Signed_command.fee_payer_pk cmd
  | Command (Zkapp_command t) ->
      Zkapp_command.fee_payer_pk t
  | Fee_transfer ft ->
      Fee_transfer.fee_payer_pk ft
  | Coinbase cb ->
      Coinbase.fee_payer_pk cb

let valid_size ~genesis_constants (t : t) =
  match t with
  | Command cmd ->
      User_command.valid_size ~genesis_constants cmd
  | Fee_transfer _ | Coinbase _ ->
      Ok ()

let check_well_formedness ~genesis_constants (t : t) =
  match t with
  | Command cmd ->
      User_command.check_well_formedness ~genesis_constants cmd
  | Fee_transfer _ | Coinbase _ ->
      Ok ()

let yojson_summary_of_command =
  let is_proof upd =
    match Account_update.authorization upd with Proof _ -> true | _ -> false
  in
  let zkapp_type cmd =
    let updates = Zkapp_command.account_updates_list cmd in
    Printf.sprintf "zkapp:%d:%d" (List.length updates)
      (List.count updates ~f:is_proof)
  in
  let mk_record type_ memo signature =
    `List
      [ `String type_
      ; `String (Signature.to_base58_check signature)
      ; `String (Signed_command_memo.to_string_hum memo)
      ]
  in
  function
  | User_command.Zkapp_command cmd ->
      mk_record (zkapp_type cmd) (Zkapp_command.memo cmd)
        ( Zkapp_command.fee_payer_account_update cmd
        |> Account_update.Fee_payer.authorization )
  | Signed_command cmd ->
      mk_record "payment" (Signed_command.memo cmd)
        (Signed_command.signature cmd)

let yojson_summary = function
  | Command cmd ->
      yojson_summary_of_command cmd
  | Fee_transfer _ ->
      `List [ `String "fee_transfer" ]
  | Coinbase cb ->
      let amount = Currency.Amount.to_yojson @@ Coinbase.amount cb in
      `List [ `String "coinbase"; amount ]

let yojson_summary_with_status cmd_with_status =
  let status =
    Transaction_status.to_yojson (With_status.status cmd_with_status)
  in
  match yojson_summary (With_status.data cmd_with_status) with
  | `List lst ->
      `List (lst @ [ status ])
