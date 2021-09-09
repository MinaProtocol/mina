[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

module Field = Snark_params.Tick.Field

[%%else]

module Field = Snark_params_nonconsensus.Field
module Mina_base = Mina_base_nonconsensus
module Hex = Hex_nonconsensus.Hex
module Unsigned_extended = Unsigned_extended_nonconsensus.Unsigned_extended
module Signature_lib = Signature_lib_nonconsensus

[%%endif]

module Token_id = Mina_base.Token_id

module Unsigned = struct
  type t =
    { random_oracle_input: (Field.t, bool) Random_oracle_input.t
    ; command: User_command_info.Partial.t
    ; nonce: Unsigned_extended.UInt32.t }

  module Rendered = struct
    type public_key = string [@@deriving yojson]

    module Payment = struct
      type t =
        { to_: public_key [@key "to"]
        ; from: public_key
        ; fee: Unsigned_extended.UInt64.t
        ; token: Unsigned_extended.UInt64.t
        ; nonce: Unsigned_extended.UInt32.t
        ; memo: string option
        ; amount: Unsigned_extended.UInt64.t
        ; valid_until: Unsigned_extended.UInt32.t option }
      [@@deriving yojson]
    end

    module Delegation = struct
      type public_key = string [@@deriving yojson]

      type t =
        { delegator: public_key
        ; new_delegate: public_key
        ; fee: Unsigned_extended.UInt64.t
        ; nonce: Unsigned_extended.UInt32.t
        ; memo: string option
        ; valid_until: Unsigned_extended.UInt32.t option }
      [@@deriving yojson]
    end

    module Create_token = struct
      type public_key = string [@@deriving yojson]

      type t =
        { receiver: public_key
        ; disable_new_accounts: bool
        ; fee: Unsigned_extended.UInt64.t
        ; nonce: Unsigned_extended.UInt32.t
        ; memo: string option
        ; valid_until: Unsigned_extended.UInt32.t option }
      [@@deriving yojson]
    end

    module Create_token_account = struct
      type public_key = string [@@deriving yojson]

      type t =
        { token_owner: public_key
        ; receiver: public_key
        ; token: Token_id.t
        ; account_disabled: bool
        ; fee: Unsigned_extended.UInt64.t
        ; nonce: Unsigned_extended.UInt32.t
        ; memo: string option
        ; valid_until: Unsigned_extended.UInt32.t option }
      [@@deriving yojson]
    end

    module Mint_tokens = struct
      type public_key = string [@@deriving yojson]

      type t =
        { token_owner: public_key
        ; receiver: public_key
        ; token: Token_id.t
        ; amount: Unsigned_extended.UInt64.t
        ; fee: Unsigned_extended.UInt64.t
        ; nonce: Unsigned_extended.UInt32.t
        ; memo: string option
        ; valid_until: Unsigned_extended.UInt32.t option }
      [@@deriving yojson]
    end

    type t =
      { random_oracle_input: string (* hex *) [@key "randomOracleInput"]
      ; payment: Payment.t option
      ; stake_delegation: Delegation.t option [@key "stakeDelegation"]
      ; create_token: Create_token.t option [@key "createToken"]
      ; create_token_account: Create_token_account.t option
            [@key "createTokenAccount"]
      ; mint_tokens: Mint_tokens.t option [@key "mintTokens"] }
    [@@deriving yojson]
  end

  let string_of_field field =
    assert (Field.size_in_bits = 255) ;
    Field.unpack field |> List.rev
    |> Random_oracle_input.Coding.string_of_field

  let field_of_string s =
    assert (Field.size_in_bits = 255) ;
    Random_oracle_input.Coding.field_of_string s ~size_in_bits:255
    |> Result.map ~f:(fun bits -> List.rev bits |> Field.project)

  let un_pk (`Pk pk) = pk

  let render_command ~nonce (command : User_command_info.Partial.t) =
    let open Result.Let_syntax in
    match command.kind with
    | `Payment ->
        let%bind amount =
          Result.of_option command.amount
            ~error:
              (Errors.create
                 (`Operations_not_valid
                   [Errors.Partial_reason.Amount_not_some]))
        in
        let payment =
          { Rendered.Payment.to_= un_pk command.receiver
          ; from= un_pk command.source
          ; fee= command.fee
          ; nonce
          ; token= command.token
          ; memo= None
          ; amount
          ; valid_until= None }
        in
        Result.return (`Payment payment)
    | `Delegation ->
        let delegation =
          { Rendered.Delegation.delegator= un_pk command.source
          ; new_delegate= un_pk command.receiver
          ; fee= command.fee
          ; nonce
          ; memo= None
          ; valid_until= None }
        in
        Result.return (`Delegation delegation)
    | `Create_token ->
        let create_token =
          { Rendered.Create_token.receiver= un_pk command.receiver
          ; disable_new_accounts= false
          ; fee= command.fee
          ; nonce
          ; memo= None
          ; valid_until= None }
        in
        Result.return (`Create_token create_token)
    | `Create_token_account ->
        let create_token_account =
          { Rendered.Create_token_account.token_owner= un_pk command.source
          ; receiver= un_pk command.receiver
          ; token= command.token |> Token_id.of_uint64
          ; account_disabled= false
          ; fee= command.fee
          ; nonce
          ; memo= None
          ; valid_until= None }
        in
        Result.return (`Create_token_account create_token_account)
    | `Mint_tokens ->
        let%bind amount =
          Result.of_option command.amount
            ~error:
              (Errors.create
                 (`Operations_not_valid
                   [Errors.Partial_reason.Amount_not_some]))
        in
        let mint_tokens =
          { Rendered.Mint_tokens.token_owner= un_pk command.source
          ; receiver= un_pk command.receiver
          ; token= command.token |> Token_id.of_uint64
          ; amount
          ; fee= command.fee
          ; nonce
          ; memo= None
          ; valid_until= None }
        in
        Result.return (`Mint_tokens mint_tokens)

  let render (t : t) =
    let open Result.Let_syntax in
    let random_oracle_input =
      Random_oracle_input.Coding.serialize ~string_of_field ~to_bool:Fn.id
        ~of_bool:Fn.id t.random_oracle_input
      |> Hex.Safe.to_hex
    in
    match%map render_command ~nonce:t.nonce t.command with
    | `Payment payment ->
        { Rendered.random_oracle_input
        ; payment= Some payment
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= None
        ; mint_tokens= None }
    | `Delegation delegation ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= Some delegation
        ; create_token= None
        ; create_token_account= None
        ; mint_tokens= None }
    | `Create_token create_token ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= None
        ; create_token= Some create_token
        ; create_token_account= None
        ; mint_tokens= None }
    | `Create_token_account create_token_account ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= Some create_token_account
        ; mint_tokens= None }
    | `Mint_tokens mint_tokens ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= None
        ; mint_tokens= Some mint_tokens }

  let of_rendered_payment (r : Rendered.Payment.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver= `Pk r.to_
    ; source= `Pk r.from
    ; kind= `Payment
    ; fee_payer= `Pk r.from
    ; fee_token= r.token
    ; token= r.token
    ; fee= r.fee
    ; amount= Some r.amount }

  let of_rendered_delegation (r : Rendered.Delegation.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver= `Pk r.new_delegate
    ; source= `Pk r.delegator
    ; kind= `Delegation
    ; fee_payer= `Pk r.delegator
    ; fee_token= Mina_base.Token_id.(default |> to_uint64)
    ; token= Mina_base.Token_id.(default |> to_uint64)
    ; fee= r.fee
    ; amount= None }

  let of_rendered_create_token (r : Rendered.Create_token.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver= `Pk r.receiver
    ; source= `Pk r.receiver
    ; kind= `Create_token
    ; fee_payer= `Pk r.receiver (* TODO: reviewer, please check! *)
    ; fee_token= Mina_base.Token_id.(default |> to_uint64)
    ; token= Mina_base.Token_id.(default |> to_uint64)
    ; fee= r.fee
    ; amount= None }

  let of_rendered_create_token_account (r : Rendered.Create_token_account.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver= `Pk r.receiver
    ; source= `Pk r.token_owner
    ; kind= `Create_token
    ; fee_payer= `Pk r.receiver
    ; fee_token= Mina_base.Token_id.(default |> to_uint64)
    ; token= r.token |> Mina_base.Token_id.to_uint64
    ; fee= r.fee
    ; amount= None }

  let of_rendered_mint_tokens (r : Rendered.Mint_tokens.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver= `Pk r.receiver
    ; source= `Pk r.token_owner
    ; kind= `Mint_tokens
    ; fee_payer= `Pk r.token_owner
    ; fee_token= Mina_base.Token_id.(default |> to_uint64)
    ; token= r.token |> Mina_base.Token_id.to_uint64
    ; fee= r.fee
    ; amount= Some r.amount }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    let open Result.Let_syntax in
    let%bind random_oracle_input =
      Random_oracle_input.Coding.deserialize ~field_of_string ~of_bool:Fn.id
        (String.to_list
           (Option.value_exn (Hex.Safe.of_hex r.random_oracle_input)))
      |> Result.map_error ~f:(fun e ->
             let parse_context =
               match e with
               | `Expected_eof ->
                   "Extra bytes at the end of input"
               | `Unexpected_eof ->
                   "Unexpected end of bytes stream"
             in
             Errors.create
               ~context:
                 (sprintf "Random oracle input deserialization: %s"
                    parse_context)
               (`Json_parse None) )
    in
    match
      ( r.payment
      , r.stake_delegation
      , r.create_token
      , r.create_token_account
      , r.mint_tokens )
    with
    | Some payment, None, None, None, None ->
        Result.return
          { command= of_rendered_payment payment
          ; random_oracle_input
          ; nonce= payment.nonce }
    | None, Some delegation, None, None, None ->
        Result.return
          { command= of_rendered_delegation delegation
          ; random_oracle_input
          ; nonce= delegation.nonce }
    | None, None, Some create_token, None, None ->
        Result.return
          { command= of_rendered_create_token create_token
          ; random_oracle_input
          ; nonce= create_token.nonce }
    | None, None, None, Some create_token_account, None ->
        Result.return
          { command= of_rendered_create_token_account create_token_account
          ; random_oracle_input
          ; nonce= create_token_account.nonce }
    | None, None, None, None, Some mint_tokens ->
        Result.return
          { command= of_rendered_mint_tokens mint_tokens
          ; random_oracle_input
          ; nonce= mint_tokens.nonce }
    | _ ->
        Result.fail
          (Errors.create ~context:"Unsigned transaction un-rendering"
             `Unsupported_operation_for_construction)
end

module Signed = struct
  type t =
    { command: User_command_info.Partial.t
    ; nonce: Unsigned_extended.UInt32.t
    ; signature: string }

  module Rendered = struct
    type t =
      { signature: string
      ; payment: Unsigned.Rendered.Payment.t option
      ; stake_delegation: Unsigned.Rendered.Delegation.t option
      ; create_token: Unsigned.Rendered.Create_token.t option
      ; create_token_account: Unsigned.Rendered.Create_token_account.t option
      ; mint_tokens: Unsigned.Rendered.Mint_tokens.t option }
    [@@deriving yojson]
  end

  let render (t : t) =
    let open Result.Let_syntax in
    match%map Unsigned.render_command ~nonce:t.nonce t.command with
    | `Payment payment ->
        { Rendered.signature= t.signature
        ; payment= Some payment
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= None
        ; mint_tokens= None }
    | `Delegation delegation ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= Some delegation
        ; create_token= None
        ; create_token_account= None
        ; mint_tokens= None }
    | `Create_token create_token ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= None
        ; create_token= Some create_token
        ; create_token_account= None
        ; mint_tokens= None }
    | `Create_token_account create_token_account ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= Some create_token_account
        ; mint_tokens= None }
    | `Mint_tokens mint_tokens ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= None
        ; mint_tokens= Some mint_tokens }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    match
      ( r.payment
      , r.stake_delegation
      , r.create_token
      , r.create_token_account
      , r.mint_tokens )
    with
    | Some payment, None, None, None, None ->
        Result.return
          { command= Unsigned.of_rendered_payment payment
          ; nonce= payment.nonce
          ; signature= r.signature }
    | None, Some delegation, None, None, None ->
        Result.return
          { command= Unsigned.of_rendered_delegation delegation
          ; nonce= delegation.nonce
          ; signature= r.signature }
    | None, None, Some create_token, None, None ->
        Result.return
          { command= Unsigned.of_rendered_create_token create_token
          ; nonce= create_token.nonce
          ; signature= r.signature }
    | None, None, None, Some create_token_account, None ->
        Result.return
          { command=
              Unsigned.of_rendered_create_token_account create_token_account
          ; nonce= create_token_account.nonce
          ; signature= r.signature }
    | None, None, None, None, Some mint_tokens ->
        Result.return
          { command= Unsigned.of_rendered_mint_tokens mint_tokens
          ; nonce= mint_tokens.nonce
          ; signature= r.signature }
    | _ ->
        Result.fail
          (Errors.create ~context:"Signed transaction un-rendering"
             `Unsupported_operation_for_construction)
end

let to_mina_signed transaction_json =
  Or_error.try_with_join (fun () ->
      let open Or_error.Let_syntax in
      let%bind rosetta_transaction_rendered =
        Signed.Rendered.of_yojson transaction_json
        |> Result.map_error ~f:Error.of_string
      in
      let%bind rosetta_transaction =
        Signed.of_rendered rosetta_transaction_rendered
        |> Result.map_error ~f:(fun err -> Error.of_string (Errors.show err))
      in
      let valid_until, memo =
        (* This is a hack..
           TODO: Handle these properly in rosetta.
        *)
        match rosetta_transaction.command.kind with
        | `Payment ->
            ( Option.bind rosetta_transaction_rendered.payment
                ~f:(fun {valid_until; _} -> valid_until)
            , Option.bind rosetta_transaction_rendered.payment
                ~f:(fun {memo; _} -> memo) )
        | `Delegation ->
            ( Option.bind rosetta_transaction_rendered.stake_delegation
                ~f:(fun {valid_until; _} -> valid_until)
            , Option.bind rosetta_transaction_rendered.stake_delegation
                ~f:(fun {memo; _} -> memo) )
        | `Create_token ->
            ( Option.bind rosetta_transaction_rendered.create_token
                ~f:(fun {valid_until; _} -> valid_until)
            , Option.bind rosetta_transaction_rendered.create_token
                ~f:(fun {memo; _} -> memo) )
        | `Create_token_account ->
            ( Option.bind rosetta_transaction_rendered.create_token_account
                ~f:(fun {valid_until; _} -> valid_until)
            , Option.bind rosetta_transaction_rendered.create_token_account
                ~f:(fun {memo; _} -> memo) )
        | `Mint_tokens ->
            ( Option.bind rosetta_transaction_rendered.mint_tokens
                ~f:(fun {valid_until; _} -> valid_until)
            , Option.bind rosetta_transaction_rendered.mint_tokens
                ~f:(fun {memo; _} -> memo) )
      in
      let pk (`Pk x) =
        Signature_lib.Public_key.Compressed.of_base58_check_exn x
      in
      let%bind payload =
        User_command_info.Partial.to_user_command_payload
          rosetta_transaction.command ~nonce:rosetta_transaction.nonce ?memo
          ?valid_until
        |> Result.map_error ~f:(fun err -> Error.of_string (Errors.show err))
      in
      let%map signature =
        match Mina_base.Signature.Raw.decode rosetta_transaction.signature with
        | Some signature ->
            Ok signature
        | None ->
            Or_error.errorf "Could not decode signature"
      in
      let command : Mina_base.Signed_command.t =
        { Mina_base.Signed_command.Poly.signature
        ; signer=
            pk rosetta_transaction.command.fee_payer
            |> Signature_lib.Public_key.decompress_exn
        ; payload }
      in
      command )
