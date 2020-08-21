open Core_kernel

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
      ; nonce: Unsigned_extended.UInt32.t
      ; memo: string option
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
  let un_pk (`Pk pk) = pk in
  let random_oracle_input =
    Random_oracle_input.Coding.serialize ~string_of_field ~to_bool:Fn.id
      ~of_bool:Fn.id t.random_oracle_input
  in
  match t.command.kind with
  | `Payment ->
      let payment =
        { Rendered.Payment.to_= un_pk t.command.receiver
        ; from= un_pk t.command.source
        ; fee= t.command.fee
        ; nonce= t.nonce
        ; memo= None
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
