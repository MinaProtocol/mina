open Core_kernel
module Field = Snark_params.Tick.Field
module Token_id = Mina_base.Token_id

module Unsigned = struct
  type t =
    { random_oracle_input : (Field.t, bool) Random_oracle_input.Legacy.t
    ; command : User_command_info.Partial.t
    ; nonce : Unsigned_extended.UInt32.t
    }

  module Rendered = struct
    type public_key = string [@@deriving yojson]

    module Payment = struct
      type t =
        { to_ : public_key [@key "to"]
        ; from : public_key
        ; fee : Unsigned_extended.UInt64.t
        ; token : string
        ; nonce : Unsigned_extended.UInt32.t
        ; memo : string option
        ; amount : Unsigned_extended.UInt64.t
        ; valid_until : Unsigned_extended.UInt32.t option
        }
      [@@deriving yojson]
    end

    module Delegation = struct
      type public_key = string [@@deriving yojson]

      type t =
        { delegator : public_key
        ; new_delegate : public_key
        ; fee : Unsigned_extended.UInt64.t
        ; nonce : Unsigned_extended.UInt32.t
        ; memo : string option
        ; valid_until : Unsigned_extended.UInt32.t option
        }
      [@@deriving yojson]
    end

    type t =
      { random_oracle_input : string (* hex *) [@key "randomOracleInput"]
      ; signer_input : Random_oracle_input.Legacy.Coding2.Rendered.t
            [@key "signerInput"]
      ; payment : Payment.t option
      ; stake_delegation : Delegation.t option [@key "stakeDelegation"]
      }
    [@@deriving yojson]
  end

  let string_of_field field =
    assert (Field.size_in_bits = 255) ;
    Field.unpack field |> List.rev
    |> Random_oracle_input.Legacy.Coding.string_of_field

  let field_of_string s =
    assert (Field.size_in_bits = 255) ;
    Random_oracle_input.Legacy.Coding.field_of_string s ~size_in_bits:255
    |> Result.map ~f:(fun bits -> List.rev bits |> Field.project)

  let un_pk (`Pk pk) = pk

  let un_token_id (`Token_id id) = id

  let render_command ~nonce (command : User_command_info.Partial.t) =
    let open Result.Let_syntax in
    match command.kind with
    | `Payment ->
        let%bind amount =
          Result.of_option command.amount
            ~error:
              (Errors.create
                 (`Operations_not_valid
                   [ Errors.Partial_reason.Amount_not_some ] ) )
        in
        let payment =
          { Rendered.Payment.to_ = un_pk command.receiver
          ; from = un_pk command.source
          ; fee = command.fee
          ; nonce
          ; token = un_token_id command.token
          ; memo = command.memo
          ; amount
          ; valid_until = command.valid_until
          }
        in
        Result.return (`Payment payment)
    | `Delegation ->
        let delegation =
          { Rendered.Delegation.delegator = un_pk command.source
          ; new_delegate = un_pk command.receiver
          ; fee = command.fee
          ; nonce
          ; memo = command.memo
          ; valid_until = command.valid_until
          }
        in
        Result.return (`Delegation delegation)

  let render (t : t) =
    let open Result.Let_syntax in
    let random_oracle_input =
      Random_oracle_input.Legacy.Coding.serialize ~string_of_field
        ~to_bool:Fn.id ~of_bool:Fn.id t.random_oracle_input
      |> Hex.Safe.to_hex
    in
    let signer_input =
      Random_oracle_input.Legacy.Coding2.serialize ~string_of_field
        ~pack:Field.project t.random_oracle_input
      |> Random_oracle_input.Legacy.Coding2.Rendered.map ~f:Hex.Safe.to_hex
    in
    match%map render_command ~nonce:t.nonce t.command with
    | `Payment payment ->
        { Rendered.random_oracle_input
        ; signer_input
        ; payment = Some payment
        ; stake_delegation = None
        }
    | `Delegation delegation ->
        { Rendered.random_oracle_input
        ; signer_input
        ; payment = None
        ; stake_delegation = Some delegation
        }

  let of_rendered_payment (r : Rendered.Payment.t) : User_command_info.Partial.t
      =
    { User_command_info.Partial.receiver = `Pk r.to_
    ; source = `Pk r.from
    ; kind = `Payment
    ; fee_payer = `Pk r.from
    ; fee_token = `Token_id r.token
    ; token = `Token_id r.token
    ; fee = r.fee
    ; amount = Some r.amount
    ; valid_until = r.valid_until
    ; memo = r.memo
    }

  let of_rendered_delegation (r : Rendered.Delegation.t) :
      User_command_info.Partial.t =
    { User_command_info.Partial.receiver = `Pk r.new_delegate
    ; source = `Pk r.delegator
    ; kind = `Delegation
    ; fee_payer = `Pk r.delegator
    ; fee_token = `Token_id Token_id.(default |> to_string)
    ; token = `Token_id Token_id.(default |> to_string)
    ; fee = r.fee
    ; amount = None
    ; valid_until = r.valid_until
    ; memo = r.memo
    }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    let open Result.Let_syntax in
    let%bind random_oracle_input =
      Random_oracle_input.Legacy.Coding.deserialize ~field_of_string
        ~of_bool:Fn.id
        (String.to_list
           (Option.value_exn (Hex.Safe.of_hex r.random_oracle_input)) )
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
                    parse_context )
               (`Json_parse None) )
    in
    match (r.payment, r.stake_delegation) with
    | Some payment, None ->
        Result.return
          { command = of_rendered_payment payment
          ; random_oracle_input
          ; nonce = payment.nonce
          }
    | None, Some delegation ->
        Result.return
          { command = of_rendered_delegation delegation
          ; random_oracle_input
          ; nonce = delegation.nonce
          }
    | _ ->
        Result.fail
          (Errors.create ~context:"Unsigned transaction un-rendering"
             `Unsupported_operation_for_construction )
end

module Signature = struct
  let decode signature_raw =
    Mina_base.Signature.Raw.decode signature_raw
    |> Result.of_option
         ~error:
           (Errors.create ~context:"Signed transaction un-rendering"
              `Unsupported_operation_for_construction )

  let encode = Mina_base.Signature.Raw.encode
end

module Signed = struct
  type t =
    { command : User_command_info.Partial.t
    ; nonce : Unsigned_extended.UInt32.t
    ; signature : Mina_base.Signature.t
    }
  [@@deriving equal]

  module Rendered = struct
    type t =
      { signature : string
      ; payment : Unsigned.Rendered.Payment.t option
      ; stake_delegation : Unsigned.Rendered.Delegation.t option
      }
    [@@deriving yojson]
  end

  let render (t : t) =
    let open Result.Let_syntax in
    let signature = Signature.encode t.signature in
    match%map Unsigned.render_command ~nonce:t.nonce t.command with
    | `Payment payment ->
        { Rendered.signature; payment = Some payment; stake_delegation = None }
    | `Delegation delegation ->
        { Rendered.signature
        ; payment = None
        ; stake_delegation = Some delegation
        }

  let of_rendered (r : Rendered.t) : (t, Errors.t) Result.t =
    let open Result.Let_syntax in
    let%bind signature = Signature.decode r.signature in
    match (r.payment, r.stake_delegation) with
    | Some payment, None ->
        Result.return
          { command = Unsigned.of_rendered_payment payment
          ; nonce = payment.nonce
          ; signature
          }
    | None, Some delegation ->
        Result.return
          { command = Unsigned.of_rendered_delegation delegation
          ; nonce = delegation.nonce
          ; signature
          }
    | _ ->
        Result.fail
          (Errors.create ~context:"Signed transaction un-rendering"
             `Unsupported_operation_for_construction )

  let to_mina_signed t =
    Or_error.try_with_join (fun () ->
        let open Or_error.Let_syntax in
        let pk (`Pk x) =
          Signature_lib.Public_key.Compressed.of_base58_check_exn x
        in
        let%map payload =
          User_command_info.Partial.to_user_command_payload t.command
            ~nonce:t.nonce
          |> Result.map_error ~f:(fun err -> Error.of_string (Errors.show err))
        in
        let command : Mina_base.Signed_command.t =
          { Mina_base.Signed_command.Poly.signature = t.signature
          ; signer =
              pk t.command.fee_payer |> Signature_lib.Public_key.decompress_exn
          ; payload
          }
        in
        command )
end

let to_mina_signed transaction_json =
  Or_error.try_with_join (fun () ->
      let open Or_error.Let_syntax in
      let%bind rendered =
        Signed.Rendered.of_yojson transaction_json
        |> Result.map_error ~f:Error.of_string
      in
      let%bind t =
        Signed.of_rendered rendered
        |> Result.map_error ~f:(fun err -> Error.of_string (Errors.show err))
      in
      Signed.to_mina_signed t )
