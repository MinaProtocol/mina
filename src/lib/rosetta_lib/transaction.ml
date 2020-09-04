[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

module Field = Snark_params.Tick.Field

[%%else]

module Field = Snark_params_nonconsensus.Field
module Coda_base = Coda_base_nonconsensus
module Hex = Hex_nonconsensus.Hex
module Unsigned_extended = Unsigned_extended_nonconsensus.Unsigned_extended

[%%endif]

module Token_id = Coda_base.Token_id

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

    type t =
      { random_oracle_input: string (* serialize |> to_hex *)
            [@key "randomOracleInput"]
      ; payment: Payment.t option
      ; stake_delegation: Delegation.t option [@key "stakeDelegation"]
      ; create_token: Create_token.t option [@key "createToken"]
      ; create_token_account: Create_token_account.t option
            [@key "createTokenAccount"] }
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
    | _ ->
        Result.fail
          (Errors.create ~context:"Unsigned transaction rendering"
             `Unsupported_operation_for_construction)

  let render (t : t) =
    let open Result.Let_syntax in
    let random_oracle_input =
      Random_oracle_input.Coding.serialize ~string_of_field ~to_bool:Fn.id
        ~of_bool:Fn.id t.random_oracle_input
    in
    match%map render_command ~nonce:t.nonce t.command with
    | `Payment payment ->
        { Rendered.random_oracle_input
        ; payment= Some payment
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= None }
    | `Delegation delegation ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= Some delegation
        ; create_token= None
        ; create_token_account= None }
    | `Create_token create_token ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= None
        ; create_token= Some create_token
        ; create_token_account= None }
    | `Create_token_account create_token_account ->
        { Rendered.random_oracle_input
        ; payment= None
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= Some create_token_account }

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
    ; fee_token= Coda_base.Token_id.(default |> to_uint64)
    ; token= Coda_base.Token_id.(default |> to_uint64)
    ; fee= r.fee
    ; amount= None }

  let of_rendered_create_token (r : Rendered.Create_token.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver= `Pk r.receiver
    ; source= `Pk r.receiver
    ; kind= `Create_token
    ; fee_payer= `Pk r.receiver (* TODO: reviewer, please check! *)
    ; fee_token= Coda_base.Token_id.(default |> to_uint64)
    ; token= Coda_base.Token_id.(default |> to_uint64)
    ; fee= r.fee
    ; amount= None }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    let open Result.Let_syntax in
    let%bind random_oracle_input =
      Random_oracle_input.Coding.deserialize ~field_of_string ~of_bool:Fn.id
        (String.to_list r.random_oracle_input)
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
    match (r.payment, r.stake_delegation, r.create_token) with
    | Some payment, None, None ->
        Result.return
          { command= of_rendered_payment payment
          ; random_oracle_input
          ; nonce= payment.nonce }
    | None, Some delegation, None ->
        Result.return
          { command= of_rendered_delegation delegation
          ; random_oracle_input
          ; nonce= delegation.nonce }
    | None, None, Some create_token ->
        Result.return
          { command= of_rendered_create_token create_token
          ; random_oracle_input
          ; nonce= create_token.nonce }
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
      }
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
        ; create_token_account= None }
    | `Delegation delegation ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= Some delegation
        ; create_token= None
        ; create_token_account= None }
    | `Create_token create_token ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= None
        ; create_token= Some create_token
        ; create_token_account= None }
    | `Create_token_account create_token_account ->
        { Rendered.signature= t.signature
        ; payment= None
        ; stake_delegation= None
        ; create_token= None
        ; create_token_account= Some create_token_account }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    match (r.payment, r.stake_delegation, r.create_token) with
    | Some payment, None, None ->
        Result.return
          { command= Unsigned.of_rendered_payment payment
          ; nonce= payment.nonce
          ; signature= r.signature }
    | None, Some delegation, None ->
        Result.return
          { command= Unsigned.of_rendered_delegation delegation
          ; nonce= delegation.nonce
          ; signature= r.signature }
    | None, None, Some create_token ->
        Result.return
          { command= Unsigned.of_rendered_create_token create_token
          ; nonce= create_token.nonce
          ; signature= r.signature }
    | _ ->
        Result.fail
          (Errors.create ~context:"Signed transaction un-rendering"
             `Unsupported_operation_for_construction)
end
