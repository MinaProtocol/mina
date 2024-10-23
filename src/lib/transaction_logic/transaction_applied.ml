open Core_kernel
open Mina_base
open Signature_lib
open Mina_transaction
module UC = Signed_command

module Signed_command_applied = struct
  module Common = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          { user_command : Signed_command.Stable.V2.t With_status.Stable.V2.t }
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Body = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Payment of { new_accounts : Account_id.Stable.V2.t list }
          | Stake_delegation of
              { previous_delegate : Public_key.Compressed.Stable.V1.t option }
          | Failed
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = { common : Common.Stable.V2.t; body : Body.Stable.V2.t }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  let new_accounts (t : t) =
    match t.body with
    | Payment { new_accounts; _ } ->
        new_accounts
    | Stake_delegation _ | Failed ->
        []
end

module Zkapp_command_applied = struct
  module T = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type 'command t =
          { accounts :
              (Account_id.Stable.V2.t * Account.Stable.V2.t option) list
          ; command : 'command With_status.Stable.V2.t
          ; new_accounts : Account_id.Stable.V2.t list
          }
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  module Wire = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = Zkapp_command.Wire.Stable.V1.t T.Stable.V1.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  type t = Zkapp_command.t T.t [@@deriving sexp, to_yojson]

  let of_wire : Wire.t -> t =
   fun { accounts; command; new_accounts } ->
    let command = With_status.map command ~f:Zkapp_command.of_wire in
    { accounts; command; new_accounts }

  let to_wire : t -> Wire.t =
   fun { accounts; command; new_accounts } ->
    let command = With_status.map command ~f:Zkapp_command.to_wire in
    { accounts; command; new_accounts }
end

module Command_applied = struct
  module Wire = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Signed_command of Signed_command_applied.Stable.V2.t
          | Zkapp_command of Zkapp_command_applied.Wire.Stable.V1.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  type t =
    | Signed_command of Signed_command_applied.t
    | Zkapp_command of Zkapp_command_applied.t
  [@@deriving sexp, to_yojson]

  let of_wire : Wire.t -> t = function
    | Signed_command sc ->
        Signed_command sc
    | Zkapp_command zc ->
        Zkapp_command (Zkapp_command_applied.of_wire zc)

  let to_wire : t -> Wire.t = function
    | Signed_command sc ->
        Signed_command sc
    | Zkapp_command zc ->
        Zkapp_command (Zkapp_command_applied.to_wire zc)
end

module Fee_transfer_applied = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { fee_transfer : Fee_transfer.Stable.V2.t With_status.Stable.V2.t
        ; new_accounts : Account_id.Stable.V2.t list
        ; burned_tokens : Currency.Amount.Stable.V1.t
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

module Coinbase_applied = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { coinbase : Coinbase.Stable.V1.t With_status.Stable.V2.t
        ; new_accounts : Account_id.Stable.V2.t list
        ; burned_tokens : Currency.Amount.Stable.V1.t
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

module Varying = struct
  module Wire = struct
    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Command of Command_applied.Wire.Stable.V2.t
          | Fee_transfer of Fee_transfer_applied.Stable.V2.t
          | Coinbase of Coinbase_applied.Stable.V2.t
        [@@deriving sexp, to_yojson]

        let to_latest = Fn.id
      end
    end]
  end

  type t =
    | Command of Command_applied.t
    | Fee_transfer of Fee_transfer_applied.t
    | Coinbase of Coinbase_applied.t
  [@@deriving sexp, to_yojson]

  let of_wire : Wire.t -> t = function
    | Fee_transfer c ->
        Fee_transfer c
    | Coinbase c ->
        Coinbase c
    | Command c ->
        Command (Command_applied.of_wire c)

  let to_wire : t -> Wire.t = function
    | Fee_transfer c ->
        Fee_transfer c
    | Coinbase c ->
        Coinbase c
    | Command c ->
        Command (Command_applied.to_wire c)
end

module Wire = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { previous_hash : Ledger_hash.Stable.V1.t
        ; varying : Varying.Wire.Stable.V2.t
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  let is_zkapp_transaction = function
    | { varying = Command (Zkapp_command _); _ } ->
        true
    | _ ->
        false
end

type t = { previous_hash : Ledger_hash.t; varying : Varying.t }
[@@deriving sexp, to_yojson]

let is_zkapp_transaction = function
  | { varying = Command (Zkapp_command _); _ } ->
      true
  | _ ->
      false

let of_wire : Wire.t -> t =
 fun { previous_hash; varying } ->
  let varying = Varying.of_wire varying in
  { previous_hash; varying }

let to_wire : t -> Wire.t =
 fun { previous_hash; varying } ->
  let varying = Varying.to_wire varying in
  { previous_hash; varying }

let burned_tokens : t -> Currency.Amount.t =
 fun { varying; _ } ->
  match varying with
  | Command _ ->
      Currency.Amount.zero
  | Fee_transfer f ->
      f.burned_tokens
  | Coinbase c ->
      c.burned_tokens

let new_accounts : t -> Account_id.t list =
 fun { varying; _ } ->
  match varying with
  | Command c -> (
      match c with
      | Signed_command sc ->
          Signed_command_applied.new_accounts sc
      | Zkapp_command zc ->
          zc.new_accounts )
  | Fee_transfer f ->
      f.new_accounts
  | Coinbase c ->
      c.new_accounts

let supply_increase :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> t
    -> Currency.Amount.Signed.t Or_error.t =
 fun ~constraint_constants t ->
  let open Or_error.Let_syntax in
  let burned_tokens = Currency.Amount.Signed.of_unsigned (burned_tokens t) in
  let account_creation_fees =
    let account_creation_fee_int =
      constraint_constants.account_creation_fee |> Currency.Fee.to_nanomina_int
    in
    let num_accounts_created = List.length @@ new_accounts t in
    (* int type is OK, no danger of overflow *)
    Currency.Amount.(
      Signed.of_unsigned
      @@ of_nanomina_int_exn (account_creation_fee_int * num_accounts_created))
  in
  let txn : Transaction.t =
    match t.varying with
    | Command (Signed_command { common = { user_command = { data; _ }; _ }; _ })
      ->
        Command (Signed_command data)
    | Command (Zkapp_command c) ->
        Command (Zkapp_command c.command.data)
    | Fee_transfer f ->
        Fee_transfer f.fee_transfer.data
    | Coinbase c ->
        Coinbase c.coinbase.data
  in
  let%bind expected_supply_increase =
    Transaction.expected_supply_increase txn
  in
  let rec process_decreases total = function
    | [] ->
        Some total
    | amt :: amts ->
        let%bind.Option sum =
          Currency.Amount.Signed.(add @@ negate amt) total
        in
        process_decreases sum amts
  in
  let total =
    process_decreases
      (Currency.Amount.Signed.of_unsigned expected_supply_increase)
      [ burned_tokens; account_creation_fees ]
  in
  Option.value_map total ~default:(Or_error.error_string "overflow")
    ~f:(fun v -> Ok v)

let transaction_with_status : t -> Transaction.t With_status.t =
 fun { varying; _ } ->
  match varying with
  | Command (Signed_command uc) ->
      With_status.map uc.common.user_command ~f:(fun cmd ->
          Transaction.Command (User_command.Signed_command cmd) )
  | Command (Zkapp_command s) ->
      With_status.map s.command ~f:(fun c ->
          Transaction.Command (User_command.Zkapp_command c) )
  | Fee_transfer f ->
      With_status.map f.fee_transfer ~f:(fun f -> Transaction.Fee_transfer f)
  | Coinbase c ->
      With_status.map c.coinbase ~f:(fun c -> Transaction.Coinbase c)

let transaction_status : t -> Transaction_status.t =
 fun { varying; _ } ->
  match varying with
  | Command (Signed_command { common = { user_command = { status; _ }; _ }; _ })
    ->
      status
  | Command (Zkapp_command c) ->
      c.command.status
  | Fee_transfer f ->
      f.fee_transfer.status
  | Coinbase c ->
      c.coinbase.status
