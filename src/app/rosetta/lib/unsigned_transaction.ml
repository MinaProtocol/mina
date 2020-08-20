open Core_kernel
module Token_id = Coda_base.Token_id

type t =
  { random_oracle_input: (Snark_params.Tick0.field, bool) Random_oracle_input.t
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
  Snark_params.Tick.Field.unpack field
  |> Random_oracle_input.Coding.string_of_field

let field_of_string s =
  assert (Snark_params.Tick.Field.size_in_bits = 255) ;
  Random_oracle_input.Coding.field_of_string s ~size_in_bits:255
  |> Result.map ~f:(fun bits -> Snark_params.Tick.Field.project bits)

let render (t : t) =
  let open User_command_info.Partial in
  let open Result.Let_syntax in
  let un_pk (`Pk pk) = pk in
  let random_oracle_input =
    Random_oracle_input.Coding.serialize ~string_of_field ~to_bool:Fn.id
      ~of_bool:Fn.id t.random_oracle_input
  in
  let%bind amount =
    Result.of_option t.command.amount
      ~error:
        (Errors.create
           (`Operations_not_valid [Errors.Partial_reason.Amount_not_some]))
  in
  match t.command.kind with
  | `Payment ->
      let payment =
        { Rendered.Payment.to_= un_pk t.command.receiver
        ; from= un_pk t.command.source
        ; fee= t.command.fee
        ; nonce= t.nonce
        ; token= t.command.token
        ; memo= None
        ; amount
        ; valid_until= None }
      in
      Result.return
        { Rendered.random_oracle_input
        ; payment= Some payment
        ; stake_delegation= None }
  | _ ->
      Result.fail
        (Errors.create ~context:"Unsigned transaction rendering"
           `Unsupported_operation_for_construction)

let of_rendered_payment (r : Rendered.Payment.t) : User_command_info.Partial.t
    =
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
               (sprintf "Random oracle input deserialization: %s" parse_context)
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

module Signed = struct
  type t =
    { command: User_command_info.Partial.t
    ; nonce: Unsigned_extended.UInt32.t
    ; signature: string }

  module Rendered = struct
    type t =
      { signature: string
      ; payment: Rendered.Payment.t option
      ; stake_delegation: Rendered.Delegation.t option }
    [@@deriving yojson]
  end

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    match (r.payment, r.stake_delegation) with
    | Some payment, None ->
        Result.return
          { command= of_rendered_payment payment
          ; nonce= payment.nonce
          ; signature= r.signature }
    | _ ->
        Result.fail
          (Errors.create ~context:"Signed transaction un-rendering"
             `Unsupported_operation_for_construction)
end
