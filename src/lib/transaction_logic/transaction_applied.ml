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
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { accounts : (Account_id.Stable.V2.t * Account.Stable.V2.t option) list
        ; command : Zkapp_command.Stable.V1.t With_status.Stable.V2.t
        ; new_accounts : Account_id.Stable.V2.t list
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  module Serializable_type = struct
    type raw_serializable = Stable.Latest.t

    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { accounts :
              (Account_id.Stable.V2.t * Account.Stable.V2.t option) list
          ; command :
              Zkapp_command.Serializable_type.Stable.V1.t
              With_status.Stable.V2.t
          ; new_accounts : Account_id.Stable.V2.t list
          }

        let to_latest = Fn.id
      end
    end]

    let to_raw_serializable : t -> raw_serializable =
     fun { accounts; command; new_accounts } ->
      { accounts
      ; command =
          With_status.map ~f:Zkapp_command.Serializable_type.to_raw_serializable
            command
      ; new_accounts
      }
  end

  type t =
    { accounts : (Account_id.t * Account.t option) list
    ; command : Zkapp_command.t With_status.t
    ; new_accounts : Account_id.t list
    }

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
      { Stable.Latest.accounts; command; new_accounts } : t =
    { accounts
    ; command =
        With_status.map
          ~f:
            (Zkapp_command.write_all_proofs_to_disk ~signature_kind
               ~proof_cache_db )
          command
    ; new_accounts
    }

  let read_all_proofs_from_disk { accounts; command; new_accounts } :
      Stable.Latest.t =
    { Stable.Latest.accounts
    ; command =
        With_status.map ~f:Zkapp_command.read_all_proofs_from_disk command
    ; new_accounts
    }

  let to_serializable_type : t -> Serializable_type.t =
   fun { accounts; command; new_accounts } ->
    { accounts
    ; command = With_status.map ~f:Zkapp_command.to_serializable_type command
    ; new_accounts
    }
end

module Command_applied = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        | Signed_command of Signed_command_applied.Stable.V2.t
        | Zkapp_command of Zkapp_command_applied.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  module Serializable_type = struct
    type toplevel = Stable.Latest.t

    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Signed_command of Signed_command_applied.Stable.V2.t
          | Zkapp_command of Zkapp_command_applied.Serializable_type.Stable.V1.t

        let to_latest = Fn.id
      end
    end]

    let to_raw_serializable : t -> toplevel = function
      | Signed_command signed_command ->
          Signed_command signed_command
      | Zkapp_command zkapp_command ->
          Zkapp_command
            (Zkapp_command_applied.Serializable_type.to_raw_serializable
               zkapp_command )
  end

  type t =
    | Signed_command of Signed_command_applied.t
    | Zkapp_command of Zkapp_command_applied.t

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db :
      Stable.Latest.t -> t = function
    | Signed_command c ->
        Signed_command c
    | Zkapp_command c ->
        Zkapp_command
          (Zkapp_command_applied.write_all_proofs_to_disk ~signature_kind
             ~proof_cache_db c )

  let read_all_proofs_from_disk : t -> Stable.Latest.t = function
    | Signed_command c ->
        Signed_command c
    | Zkapp_command c ->
        Zkapp_command (Zkapp_command_applied.read_all_proofs_from_disk c)

  let to_serializable_type : t -> Serializable_type.t = function
    | Signed_command signed_command ->
        Signed_command signed_command
    | Zkapp_command zkapp_command ->
        Zkapp_command (Zkapp_command_applied.to_serializable_type zkapp_command)
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

module Varying : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V2 : sig
      type t [@@deriving sexp, to_yojson]
    end
  end]

  module Serializable_type : sig
    type raw_serializable := Stable.Latest.t

    [%%versioned:
    module Stable : sig
      module V2 : sig
        type t
      end
    end]

    val to_raw_serializable : t -> raw_serializable
  end

  type t =
    | Command of Command_applied.t
    | Fee_transfer of Fee_transfer_applied.t
    | Coinbase of Coinbase_applied.t

  val write_all_proofs_to_disk :
       signature_kind:Mina_signature_kind.t
    -> proof_cache_db:Proof_cache_tag.cache_db
    -> Stable.Latest.t
    -> t

  val read_all_proofs_from_disk : t -> Stable.Latest.t

  val to_serializable_type : t -> Serializable_type.t
end = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        | Command of Command_applied.Stable.V2.t
        | Fee_transfer of Fee_transfer_applied.Stable.V2.t
        | Coinbase of Coinbase_applied.Stable.V2.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  module Serializable_type = struct
    type raw_serializable = Stable.Latest.t

    [%%versioned
    module Stable = struct
      module V2 = struct
        type t =
          | Command of Command_applied.Serializable_type.Stable.V2.t
          | Fee_transfer of Fee_transfer_applied.Stable.V2.t
          | Coinbase of Coinbase_applied.Stable.V2.t

        let to_latest = Fn.id
      end
    end]

    let to_raw_serializable : t -> raw_serializable = function
      | Command command ->
          Command
            (Command_applied.Serializable_type.to_raw_serializable command)
      | Fee_transfer fee_transfer ->
          Fee_transfer fee_transfer
      | Coinbase coinbase ->
          Coinbase coinbase
  end

  type t =
    | Command of Command_applied.t
    | Fee_transfer of Fee_transfer_applied.t
    | Coinbase of Coinbase_applied.t

  let write_all_proofs_to_disk ~signature_kind ~proof_cache_db :
      Stable.Latest.t -> t = function
    | Command c ->
        Command
          (Command_applied.write_all_proofs_to_disk ~signature_kind
             ~proof_cache_db c )
    | Fee_transfer f ->
        Fee_transfer f
    | Coinbase c ->
        Coinbase c

  let read_all_proofs_from_disk : t -> Stable.Latest.t = function
    | Command c ->
        Command (Command_applied.read_all_proofs_from_disk c)
    | Fee_transfer f ->
        Fee_transfer f
    | Coinbase c ->
        Coinbase c

  let to_serializable_type : t -> Serializable_type.t = function
    | Command command ->
        Command (Command_applied.to_serializable_type command)
    | Fee_transfer fee_transfer ->
        Fee_transfer fee_transfer
    | Coinbase coinbase ->
        Coinbase coinbase
end

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t =
      { previous_hash : Ledger_hash.Stable.V1.t; varying : Varying.Stable.V2.t }
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end
end]

module Serializable_type = struct
  type toplevel = Stable.Latest.t

  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { previous_hash : Ledger_hash.Stable.V1.t
        ; varying : Varying.Serializable_type.Stable.V2.t
        }

      let to_latest = Fn.id
    end
  end]

  let to_raw_serializable { previous_hash; varying } : toplevel =
    { previous_hash
    ; varying = Varying.Serializable_type.to_raw_serializable varying
    }
end

type t = { previous_hash : Ledger_hash.t; varying : Varying.t }

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

let transaction : t -> Transaction.t =
 fun { varying; _ } ->
  match varying with
  | Command (Signed_command { common = { user_command = { data; _ }; _ }; _ })
    ->
      Transaction.Command (User_command.Signed_command data)
  | Command (Zkapp_command { command = { data; _ }; _ }) ->
      Transaction.Command (User_command.Zkapp_command data)
  | Fee_transfer { fee_transfer = { data; _ }; _ } ->
      Transaction.Fee_transfer data
  | Coinbase { coinbase = { data; _ }; _ } ->
      Transaction.Coinbase data

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

let write_all_proofs_to_disk ~signature_kind ~proof_cache_db
    { Stable.Latest.previous_hash; varying } : t =
  { previous_hash
  ; varying =
      Varying.write_all_proofs_to_disk ~signature_kind ~proof_cache_db varying
  }

let read_all_proofs_from_disk { previous_hash; varying } =
  { Stable.Latest.previous_hash
  ; varying = Varying.read_all_proofs_from_disk varying
  }

let to_serializable_type { previous_hash; varying } : Serializable_type.t =
  { previous_hash; varying = Varying.to_serializable_type varying }
