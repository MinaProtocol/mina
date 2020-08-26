open Core_kernel
module Token_id = Coda_base.Token_id

module Unsigned = struct
  type t =
    { random_oracle_input:
        (Snark_params.Tick0.field, bool) Random_oracle_input.t
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
      type t = Todo [@@deriving yojson]
    end

    type t =
      { random_oracle_input: string (* serialize |> to_hex *)
            [@key "randomOracleInput"]
      ; payment: Payment.t option
      ; stake_delegation: Delegation.t option [@key "stakeDelegation"] }
    [@@deriving yojson]
  end

  let string_of_field field =
    assert (Snark_params.Tick.Field.size_in_bits = 255) ;
    Rosetta_lib.Coding.of_field field |> Hex.Safe.of_hex |> Option.value_exn

  let field_of_string s =
    assert (Snark_params.Tick.Field.size_in_bits = 255) ;
    Hex.Safe.to_hex s |> Rosetta_lib.Coding.to_field

  let un_pk (`Pk pk) = pk

  let render_command ~nonce (command : User_command_info.Partial.t) =
    let open Result.Let_syntax in
    let%bind amount =
      Result.of_option command.amount
        ~error:
          (Errors.create
             (`Operations_not_valid [Errors.Partial_reason.Amount_not_some]))
    in
    match command.kind with
    | `Payment ->
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
    let%map (`Payment payment) = render_command ~nonce:t.nonce t.command in
    { Rendered.random_oracle_input
    ; payment= Some payment
    ; stake_delegation= None }

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
    match (r.payment, r.stake_delegation) with
    | Some payment, None ->
        Result.return
          { command= of_rendered_payment payment
          ; random_oracle_input
          ; nonce= payment.nonce }
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
      ; stake_delegation: Unsigned.Rendered.Delegation.t option }
    [@@deriving yojson]
  end

  let render (t : t) =
    let open Result.Let_syntax in
    let%map (`Payment payment) =
      Unsigned.render_command ~nonce:t.nonce t.command
    in
    { Rendered.signature= t.signature
    ; payment= Some payment
    ; stake_delegation= None }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    match (r.payment, r.stake_delegation) with
    | Some payment, None ->
        Result.return
          { command= Unsigned.of_rendered_payment payment
          ; nonce= payment.nonce
          ; signature= r.signature }
    | _ ->
        Result.fail
          (Errors.create ~context:"Signed transaction un-rendering"
             `Unsupported_operation_for_construction)
end
