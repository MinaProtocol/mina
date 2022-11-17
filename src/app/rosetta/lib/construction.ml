module Scalars = Graphql_lib.Scalars

module Get_options_metadata =
[%graphql
{|
    query get_options_metadata($sender: PublicKey!, $token_id: TokenId, $receiver_key: PublicKey!) {
      bestChain(maxLength: 5) {
        transactions {
          userCommands {
            fee @ppxCustom(module: "Scalars.UInt64")
          }
        }
      }

      receiver: account(publicKey: $receiver_key, token: $token_id) {
        nonce
      }

      account(publicKey: $sender, token: $token_id) {
        balance {
          blockHeight @ppxCustom(module: "Scalars.UInt32")
          stateHash
        }
        nonce
      }
      daemonStatus {
        chainId
      }
      initialPeers
     }
|}]

module Send_payment =
[%graphql
{|
  mutation send($from: PublicKey!, $to_: PublicKey!, $token: UInt64,
                $amount: UInt64!, $fee: UInt64!, $validUntil: UInt64,
                $memo: String, $nonce: UInt32!, $signature: String!) {
    sendPayment(signature: {rawSignature: $signature}, input:
                  {from: $from, to:$to_, token:$token, amount:$amount,
                  fee:$fee, validUntil: $validUntil, memo: $memo, nonce:$nonce}) {
      payment {
        hash @ppxCustom(module: "Scalars.String_json")
      }
  }}
  |}]

module Send_delegation =
[%graphql
{|
mutation ($sender: PublicKey!,
          $receiver: PublicKey!,
          $fee: UInt64!,
          $nonce: UInt32!,
          $memo: String,
          $signature: String!) {
  sendDelegation(signature: {rawSignature: $signature}, input:
    {from: $sender, to: $receiver, fee: $fee, memo: $memo, nonce: $nonce}) {
    delegation {
      hash @ppxCustom(module: "Scalars.String_json")
    }
  }
}
|}]

(* Avoid shadowing graphql_ppx functions *)
open Core_kernel
open Async
open Rosetta_lib

(* Rosetta_models.Currency shadows our Currency so we "save" it as MinaCurrency first *)
module Mina_currency = Currency
open Rosetta_models
module Signature = Mina_base.Signature
module Transaction = Rosetta_lib.Transaction
module Public_key = Signature_lib.Public_key
module Signed_command_payload = Mina_base.Signed_command_payload
module User_command = Mina_base.User_command
module Signed_command = Mina_base.Signed_command
module Transaction_hash = Mina_transaction.Transaction_hash

module Options = struct
  type t =
    { sender : Public_key.Compressed.t
    ; token_id : string
    ; receiver : Public_key.Compressed.t
    ; valid_until : Unsigned_extended.UInt32.t option
    ; memo : string option
    }

  module Raw = struct
    type t =
      { sender : string
      ; token_id : string
      ; receiver : string
      ; valid_until : string option [@default None]
      ; memo : string option [@default None]
      }
    [@@deriving yojson]
  end

  let to_json t =
    { Raw.sender = Public_key.Compressed.to_base58_check t.sender
    ; token_id = t.token_id
    ; receiver = Public_key.Compressed.to_base58_check t.receiver
    ; valid_until =
        Option.map ~f:Unsigned_extended.UInt32.to_string t.valid_until
    ; memo = t.memo
    }
    |> Raw.to_yojson

  let of_json r =
    Raw.of_yojson r
    |> Result.map_error ~f:(fun e ->
           Errors.create ~context:"Options of_json" (`Json_parse (Some e)))
    |> Result.bind ~f:(fun (r : Raw.t) ->
           let open Result.Let_syntax in
           let error which e =
              Errors.create
                ~context:("Options of_json bad public key (" ^ which ^ ")")
                (`Json_parse (Some (Core_kernel.Error.to_string_hum e)))
           in
           let%bind sender =
             Public_key.Compressed.of_base58_check r.sender
             |> Result.map_error ~f:(error "sender")
           in
           let%map receiver =
             Public_key.Compressed.of_base58_check r.receiver
             |> Result.map_error ~f:(error "receiver")
           in
           { sender
           ; token_id = r.token_id
           ; receiver
           ; valid_until =
               Option.map ~f:Unsigned_extended.UInt32.of_string r.valid_until
           ; memo = r.memo
           })
end

(* TODO: unify handling of json between this and Options (above) and everything else in rosetta *)
module Metadata_data = struct
  type t =
    { sender : string
    ; nonce : Unsigned_extended.UInt32.t
    ; token_id : string
    ; receiver : string
    ; account_creation_fee : Unsigned_extended.UInt64.t option [@default None]
    ; valid_until : Unsigned_extended.UInt32.t option [@default None]
    ; memo : string option [@default None]
    }
  [@@deriving yojson]

  let create ~nonce ~sender ~token_id ~receiver ~account_creation_fee
      ~valid_until ~memo =
    { sender = Public_key.Compressed.to_base58_check sender
    ; nonce
    ; token_id
    ; receiver = Public_key.Compressed.to_base58_check receiver
    ; account_creation_fee
    ; valid_until
    ; memo
    }

  let of_json r =
    of_yojson r
    |> Result.map_error ~f:(fun e ->
           Errors.create ~context:"Options of_json" (`Json_parse (Some e)))
end

module Derive = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = { lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = { lift = Deferred.return }

    let mock : Mock.t = { lift = Fn.id }
  end

  module Impl (M : Monad_fail.S) = struct
    module Token_id_decode = Amount_of.Token_id.T (M)

    let handle ~(env : Env.T(M).t) (req : Construction_derive_request.t) =
      let open M.Let_syntax in
      let hex_bytes = req.public_key.hex_bytes in
      let%bind pk_compressed =
        let pk_or_error =
          try Ok (Rosetta_coding.Coding.to_public_key_compressed hex_bytes)
          with exn -> Error (Core_kernel.Error.of_exn exn)
        in
        env.lift
        @@ Result.map_error
             ~f:(fun _ -> Errors.create `Malformed_public_key)
             pk_or_error
      in
      let%map token_id = Token_id_decode.decode req.metadata in
      { Construction_derive_response.address = None
      ; account_identifier =
          Some
            (User_command_info.account_id
               (`Pk (Public_key.Compressed.to_base58_check pk_compressed))
               (`Token_id (Option.value ~default:Amount_of.Token_id.default token_id)))
      ; metadata = None
      }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Metadata = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql :
               ?token_id:string
            -> address:Public_key.Compressed.t
            -> receiver:Public_key.Compressed.t
            -> unit
            -> ('gql, Errors.t) M.t
        ; validate_network_choice :
               network_identifier:Network_identifier.t
            -> graphql_uri:Uri.t
            -> (unit, Errors.t) M.t
        ; lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t
        }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : graphql_uri:Uri.t -> 'gql Real.t =
     fun ~graphql_uri ->
      { gql =
          (fun ?token_id:_ ~address ~receiver () ->
            Graphql.query
              Get_options_metadata.(make @@ makeVariables
                 ~sender:
                   (`String (Public_key.Compressed.to_base58_check address))
                   (* for now, nonce is based on the fee payer's account using the default token,
                      per @mrmr1993
                   *)
                 ~token_id:
                   (`String Mina_base.Token_id.(default |> to_string))
                   (* WAS:
                      ( match token_id with
                      | Some x ->
                          `String (Unsigned.UInt64.to_string x)
                      | None ->
                          `Null )
                   *)
                 ~receiver_key:
                   (`String (Public_key.Compressed.to_base58_check receiver))
                 ())
              graphql_uri)
      ; validate_network_choice = Network.Validate_choice.Real.validate
      ; lift = Deferred.return
      }
  end

  (* Invariant: fees is sorted *)
  module type Field_like = sig
    type t

    val of_int : int -> t

    val ( + ) : t -> t -> t

    val ( - ) : t -> t -> t

    val ( * ) : t -> t -> t

    val ( / ) : t -> t -> t
  end

  let suggest_fee (type a) (module F : Field_like with type t = a) fees =
    let len = Array.length fees in
    let med = fees.(len / 2) in
    let iqr =
      let threeq = fees.(3 * len / 4) in
      let oneq = fees.(len / 4) in
      F.(threeq - oneq)
    in
    let open F in
    med + (iqr / of_int 2)

  let%test_unit "suggest_fee is reasonable" =
    let sugg =
      suggest_fee (module Int) [| 100; 200; 300; 400; 500; 600; 700; 800 |]
    in
    [%test_eq: int] sugg 700

  module Impl (M : Monad_fail.S) = struct
    let handle ~graphql_uri ~(env : 'gql Env.T(M).t)
        (req : Construction_metadata_request.t) =
      let open M.Let_syntax in
      let%bind req_options =
        match req.options with
        | Some options ->
            M.return options
        | None ->
            M.fail (Errors.create `No_options_provided)
      in
      let%bind options = Options.of_json req_options |> env.lift in
      let%bind res =
        env.gql ~token_id:options.token_id ~address:options.sender
          ~receiver:options.receiver ()
      in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~graphql_uri
      in
      let%bind account =
        match res.Get_options_metadata.account with
        | None ->
            M.fail
              (Errors.create
                 (`Account_not_found
                   (Public_key.Compressed.to_base58_check options.sender)))
        | Some account ->
            M.return account
      in
      let nonce = Option.value ~default:Unsigned.UInt32.zero account.nonce
      in
      (* suggested fee *)
      (* Take the median of all the fees in blocks and add a bit extra using
       * the interquartile range *)
      let%map suggested_fee =
        let%map fees =
          match res.bestChain with
          | Some chain ->
              let a =
                Array.fold chain ~init:[] ~f:(fun fees block ->
                    Array.fold block.transactions.userCommands ~init:fees
                      ~f:(fun fees cmd -> cmd.fee :: fees))
                |> Array.of_list
              in
              Array.sort a ~compare:Unsigned_extended.UInt64.compare ;
              M.return a
          | None ->
              M.fail (Errors.create `Chain_info_missing)
        in
        Amount_of.mina
          (suggest_fee
             ( module struct
               include Unsigned_extended.UInt64
               include Infix
             end )
             fees)
      in
      (* minimum fee : Pull this from the compile constants *)
      let amount_metadata =
        `Assoc
          [ ( "minimum_fee"
            , Amount.to_yojson
                (Amount_of.mina
                   (Mina_currency.Fee.to_uint64
                      Mina_compile_config.minimum_user_command_fee)) )
          ]
      in
      let receiver_exists =
        Option.is_some res.receiver
      in
      let constraint_constants =
        Genesis_constants.Constraint_constants.compiled
      in
      { Construction_metadata_response.metadata =
          Metadata_data.create ~sender:options.Options.sender
            ~token_id:options.Options.token_id ~nonce ~receiver:options.receiver
            ~account_creation_fee:
              ( if receiver_exists then None
              else
                Some
                  (Mina_currency.Fee.to_uint64
                     constraint_constants.account_creation_fee) )
            ~valid_until:options.valid_until
            ~memo:options.memo
          |> Metadata_data.to_yojson
      ; suggested_fee =
          [ { suggested_fee with metadata = Some amount_metadata } ]
      }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Preprocess = struct
  module Metadata = struct
    type t = { valid_until : Unsigned_extended.UInt32.t option [@default None]; memo: string option [@default None] }
    [@@deriving yojson]

    let of_json r =
      of_yojson r
      |> Result.map_error ~f:(fun e ->
             Errors.create ~context:"Preprocess metadata of_json"
               (`Json_parse (Some e)))
  end

  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = { lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = { lift = Deferred.return }

    let mock : Mock.t = { lift = Fn.id }
  end

  module Impl (M : Monad_fail.S) = struct
    let lift_reason_validation_to_errors ~(env : Env.T(M).t) t =
      Result.map_error t ~f:(fun reasons ->
          Errors.create (`Operations_not_valid reasons))
      |> env.lift

    let handle ~(env : Env.T(M).t) (req : Construction_preprocess_request.t) =
      let open M.Let_syntax in
      let%bind metadata =
        match req.metadata with
        | Some json ->
            Metadata.of_json json |> env.lift |> M.map ~f:Option.return
        | None ->
            M.return None
      in
      let%bind partial_user_command =
        User_command_info.of_operations req.operations
        |> lift_reason_validation_to_errors ~env
      in
      let key (`Pk pk) =
        Public_key.Compressed.of_base58_check pk
        |> Result.map_error ~f:(fun _ ->
               Errors.create `Public_key_format_not_valid)
        |> env.lift
      in
      let%bind sender =
        key partial_user_command.User_command_info.Partial.source
      in
      let%map receiver =
        key partial_user_command.User_command_info.Partial.receiver
      in
      { Construction_preprocess_response.options =
          Some
            (Options.to_json
               { Options.sender
               ; token_id = (match  partial_user_command.User_command_info.Partial.token
                             with `Token_id s -> s)
               ; receiver
               ; valid_until = Option.bind ~f:(fun m -> m.valid_until) metadata
               ; memo = Option.bind ~f:(fun m -> m.memo) metadata
               })
      ; required_public_keys = []
      }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Payloads = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = { lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = { lift = Deferred.return }

    let mock : Mock.t = { lift = Fn.id }
  end

  module Impl (M : Monad_fail.S) = struct
    let lift_reason_validation_to_errors ~(env : Env.T(M).t) t =
      Result.map_error t ~f:(fun reasons ->
          Errors.create (`Operations_not_valid reasons))
      |> env.lift

    let handle ~(env : Env.T(M).t) (req : Construction_payloads_request.t) =
      let open M.Let_syntax in
      let%bind metadata =
        match req.metadata with
        | Some json ->
            Metadata_data.of_json json |> env.lift
        | None ->
            M.fail
              (Errors.create
                 ~context:"Metadata is required for payloads request"
                 (`Json_parse None))
      in
      let%bind partial_user_command =
        User_command_info.of_operations ?valid_until:metadata.valid_until
        ?memo:metadata.memo
          req.operations
        |> lift_reason_validation_to_errors ~env
      in
      let%bind () =
        let (`Pk pk) = partial_user_command.User_command_info.Partial.source in
        Public_key.Compressed.of_base58_check pk
        |> Result.map_error ~f:(fun _ ->
               Errors.create ~context:"compression" `Public_key_format_not_valid)
        |> Result.bind ~f:(fun pk ->
               Result.of_option (Public_key.decompress pk)
                 ~error:
                   (Errors.create ~context:"decompression"
                      `Public_key_format_not_valid))
        |> Result.map ~f:Rosetta_coding.Coding.of_public_key
        |> Result.map ~f:ignore
        |> env.lift
      in
      let%bind user_command_payload =
        User_command_info.Partial.to_user_command_payload ~nonce:metadata.nonce
          partial_user_command
        |> env.lift
      in
      let random_oracle_input = Signed_command.to_input_legacy user_command_payload in
      let%map unsigned_transaction_string =
        { Transaction.Unsigned.random_oracle_input
        ; command = partial_user_command
        ; nonce = metadata.nonce
        }
        |> Transaction.Unsigned.render
        |> Result.map ~f:Transaction.Unsigned.Rendered.to_yojson
        |> Result.map ~f:Yojson.Safe.to_string
        |> env.lift
      in
      { Construction_payloads_response.unsigned_transaction =
          unsigned_transaction_string
      ; payloads =
          [ { Signing_payload.address = None
            ; account_identifier =
                Some
                  (User_command_info.account_id
                     partial_user_command.User_command_info.Partial.source
                     partial_user_command.User_command_info.Partial.token)
            ; hex_bytes = Hex.Safe.to_hex unsigned_transaction_string
            ; signature_type = Some `Schnorr_poseidon
            }
          ]
      }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Combine = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = { lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = { lift = Deferred.return }

    let mock : Mock.t = { lift = Fn.id }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : Env.T(M).t) (req : Construction_combine_request.t) =
      let open M.Let_syntax in
      let%bind json =
        try M.return (Yojson.Safe.from_string req.unsigned_transaction)
        with _ -> M.fail (Errors.create (`Json_parse None))
      in
      let%bind unsigned_transaction =
        Transaction.Unsigned.Rendered.of_yojson json
        |> Result.map_error ~f:(fun e -> Errors.create (`Json_parse (Some e)))
        |> Result.bind ~f:Transaction.Unsigned.of_rendered
        |> env.lift
      in
      (* TODO: validate that public key is correct w.r.t. signature for this transaction *)
      let%bind signature =
        match req.signatures with
        | s :: _ ->
            Transaction.Signature.decode s.hex_bytes
            |> env.lift
        | _ ->
            M.fail (Errors.create `Signature_missing)
      in
      let signed_transaction_full =
        { Transaction.Signed.signature
        ; nonce = unsigned_transaction.nonce
        ; command = unsigned_transaction.command
        }
      in
      let%map rendered =
        Transaction.Signed.render signed_transaction_full |> env.lift
      in
      let signed_transaction =
        Transaction.Signed.Rendered.to_yojson rendered |> Yojson.Safe.to_string
      in
      { Construction_combine_response.signed_transaction }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Parse = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t =
        { verify_payment_signature :
               network_identifier:Rosetta_models.Network_identifier.t
            -> payment:Transaction.Unsigned.Rendered.Payment.t
            -> signature:Mina_base.Signature.t
            -> unit
            -> (bool, Errors.t) M.t
        ; lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t
        }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t =
      { verify_payment_signature =
          (fun ~network_identifier ~payment ~signature () ->
            let open Deferred.Result in
            let open Deferred.Result.Let_syntax in
            let parse_pk ~which s =
              match Public_key.Compressed.of_base58_check s with
              | Ok pk ->
                  return pk
              | Error e ->
                  Deferred.Result.fail
                    (Errors.create
                       ~context:
                         (sprintf
                            "Parsing verify_payment_signature, bad %s public \
                             key"
                            which)
                       (`Json_parse (Some (Core_kernel.Error.to_string_hum e))))
            in
            let%bind source_pk = parse_pk ~which:"source" payment.from in
            let%bind receiver_pk = parse_pk ~which:"receiver" payment.to_ in
            let body =
              Signed_command_payload.Body.Payment
                { source_pk
                ; receiver_pk
                ; amount = Mina_currency.Amount.of_uint64 payment.amount
                }
            in
            let fee_payer_pk = source_pk in
            let fee = Mina_currency.Fee.of_uint64 payment.fee in
            let signer = fee_payer_pk in
            let valid_until =
              Option.map payment.valid_until
                ~f:Mina_numbers.Global_slot.of_uint32
            in
            let nonce = payment.nonce in
            let%map memo =
              match payment.memo with
              | None -> return User_command_info.Signed_command_memo.empty
              | Some str ->
                (match
                  User_command_info.Signed_command_memo.create_from_string str
                 with
                 | Error _ -> fail (Errors.create `Memo_invalid )
                 | Ok m -> return m)
            in
            let payload =
              Signed_command_payload.create ~fee ~fee_payer_pk ~nonce
                ~valid_until ~memo ~body
            in
            (* choose signature verification based on network *)
            let signature_kind : Mina_signature_kind.t =
              if String.equal network_identifier.network "mainnet" then
                Mainnet
              else Testnet
            in
            Option.is_some @@
              Signed_command.create_with_signature_checked ~signature_kind
                signature signer payload )
      ; lift = Deferred.return
      }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : Env.T(M).t) (req : Construction_parse_request.t) =
      let open M.Let_syntax in
      let%bind json =
        try M.return (Yojson.Safe.from_string req.transaction)
        with _ -> M.fail (Errors.create (`Json_parse None))
      in
      let%map operations, account_identifier_signers, meta =
        let meta_of_command (cmd : User_command_info.Partial.t) =
          { Preprocess.Metadata.memo = cmd.memo
          ; valid_until = cmd.valid_until
          }
        in
        match req.signed with
        | true ->
            let%bind signed_rendered_transaction =
              Transaction.Signed.Rendered.of_yojson json
              |> Result.map_error ~f:(fun e ->
                     Errors.create (`Json_parse (Some e)))
              |> env.lift
            in
            let%bind signed_transaction =
              Transaction.Signed.of_rendered signed_rendered_transaction
              |> env.lift
            in
            let%map () =
              match signed_rendered_transaction.payment with
              | Some payment ->
                  (* Only perform signature validation on payments. *)
                  let%bind res =
                    env.verify_payment_signature
                      ~network_identifier:req.network_identifier ~payment
                      ~signature:signed_transaction.signature ()
                  in
                  if res then M.return ()
                  else M.fail (Errors.create `Signature_invalid)
              | None ->
                  M.return ()
            in
            ( User_command_info.to_operations ~failure_status:None
                signed_transaction.command
            , [ User_command_info.account_id signed_transaction.command.source
                  signed_transaction.command.token
              ]
            , meta_of_command signed_transaction.command)
        | false ->
            let%map unsigned_transaction =
              Transaction.Unsigned.Rendered.of_yojson json
              |> Result.map_error ~f:(fun e ->
                     Errors.create (`Json_parse (Some e)))
              |> Result.bind ~f:Transaction.Unsigned.of_rendered
              |> env.lift
            in
            ( User_command_info.to_operations ~failure_status:None
                unsigned_transaction.command
            , []
            , meta_of_command unsigned_transaction.command)
      in
      { Construction_parse_response.operations
      ; signers = []
      ; account_identifier_signers
      ; metadata =
        match (meta.memo, meta.valid_until) with
        | None, None -> None
        | _ -> Some (Preprocess.Metadata.to_yojson meta)
      }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Hash = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = { lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = { lift = Deferred.return }

    let mock : Mock.t = { lift = Fn.id }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : Env.T(M).t) (req : Construction_hash_request.t) =
      let open M.Let_syntax in
      let%bind json =
        try M.return (Yojson.Safe.from_string req.signed_transaction)
        with _ -> M.fail (Errors.create (`Json_parse None))
      in
      let%bind signed_transaction =
        Transaction.Signed.Rendered.of_yojson json
        |> Result.map_error ~f:(fun e -> Errors.create (`Json_parse (Some e)))
        |> Result.bind ~f:Transaction.Signed.of_rendered
        |> env.lift
      in
      let%bind signer =
        let (`Pk pk) = signed_transaction.command.source in
        Public_key.Compressed.of_base58_check pk
        |> Result.map_error ~f:(fun _ ->
               Errors.create ~context:"compression" `Public_key_format_not_valid)
        |> Result.bind ~f:(fun pk ->
               Result.of_option (Public_key.decompress pk)
                 ~error:
                   (Errors.create ~context:"decompression"
                      `Public_key_format_not_valid))
        |> Result.map_error ~f:(fun _ -> Errors.create `Malformed_public_key)
        |> env.lift
      in
      let%map payload =
        User_command_info.Partial.to_user_command_payload
          ~nonce:signed_transaction.nonce signed_transaction.command
        |> env.lift
      in
      let full_command =
        { Signed_command.Poly.payload
        ; signature = signed_transaction.signature
        ; signer
        }
      in
      let hash =
        Transaction_hash.hash_command (User_command.Signed_command full_command)
        |> Transaction_hash.to_base58_check
      in
      Transaction_identifier_response.create
        (Transaction_identifier.create hash)
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Submit = struct
  module Sql = struct
    module Transaction_exists = struct
      type params =
        { nonce : int64
        ; source : string
        ; receiver : string
        ; amount : string
        ; fee : string
        }
      [@@deriving hlist]

      let params_typ =
        let open Mina_caqti.Type_spec in
        let spec = Caqti_type.[ int64; string; string; string; string ] in
        let encode t = Ok (hlist_to_tuple spec (params_to_hlist t)) in
        let decode t = Ok (params_of_hlist (tuple_to_hlist spec t)) in
        Caqti_type.custom ~encode ~decode (to_rep spec)

      let query =
        Caqti_request.find_opt
          params_typ
          Caqti_type.string
          {sql| SELECT uc.id FROM user_commands uc
                INNER JOIN public_keys AS pks ON pks.id = uc.source_id
                INNER JOIN public_keys AS pkr ON pkr.id = uc.receiver_id
                WHERE uc.nonce = $1
                AND pks.value = $2
                AND pkr.value = $3
                AND uc.amount = $4
                AND uc.fee = $5 |sql}

      let run (module Conn : Caqti_async.CONNECTION) ~nonce ~source ~receiver ~amount ~fee =
        let open Unsigned_extended in
        Conn.find_opt
          query
          { nonce = (UInt32.to_int64 nonce)
          ; source
          ; receiver
          ; amount = UInt64.to_string amount
          ; fee = UInt64.to_string fee
          }
        |> Deferred.Result.map ~f:Option.is_some
    end
  end

  module Env = struct
    module T (M : Monad_fail.S) = struct
      type ( 'gql_payment
           , 'gql_delegation
           , 'gql_create_token
           , 'gql_create_token_account
           , 'gql_mint_tokens )
           t =
        { gql_payment :
               payment:Transaction.Unsigned.Rendered.Payment.t
            -> signature:string
            -> unit
            -> ('gql_payment, Errors.t) M.t
              (* TODO: Validate network choice with separate query *)
        ; gql_delegation :
               delegation:Transaction.Unsigned.Rendered.Delegation.t
            -> signature:string
            -> unit
            -> ('gql_delegation, Errors.t) M.t
        ; db_transaction_exists:
               nonce:Unsigned_extended.UInt32.t
            -> source:string
            -> receiver:string
            -> amount:Unsigned_extended.UInt64.t
            -> fee:Unsigned_extended.UInt64.t
            -> (bool, Errors.t) M.t
        ; lift : 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t
        }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real :
           db:(module Caqti_async.CONNECTION)
        -> graphql_uri:Uri.t
        -> ( 'gql_payment
           , 'gql_delegation
           , 'gql_create_token
           , 'gql_create_token_account
           , 'gql_mint_tokens )
           Real.t =
      let uint64 x = `String (Unsigned.UInt64.to_string x) in
      let uint32 x = `String (Unsigned.UInt32.to_string x) in
      fun ~db ~graphql_uri ->
        { gql_payment =
            (fun ~payment ~signature () ->
              Graphql.query_and_catch
                Send_payment.(make @@ makeVariables ~from:(`String payment.from)
                   ~to_:(`String payment.to_) ~token:(`String payment.token)
                   ~amount:(uint64 payment.amount) ~fee:(uint64 payment.fee)
                   ?validUntil:(Option.map ~f:uint32 payment.valid_until)
                   ?memo:payment.memo ~nonce:(uint32 payment.nonce) ~signature
                   ())
                graphql_uri)
        ; gql_delegation =
            (fun ~delegation ~signature () ->
              Graphql.query
                Send_delegation.(make @@ makeVariables ~sender:(`String delegation.delegator)
                   ~receiver:(`String delegation.new_delegate)
                   ~fee:
                     (uint64 delegation.fee)
                   (* TODO: Enable these when graphql supports sending validUntil for these transactions *)
                   (* ?validUntil:(Option.map ~f:uint32 delegation.valid_until) *)
                   ?memo:delegation.memo ~nonce:(uint32 delegation.nonce)
                   ~signature ())
                graphql_uri)
        ; db_transaction_exists = (fun ~nonce ~source ~receiver ~amount ~fee ->
          Sql.Transaction_exists.run db ~nonce ~source ~receiver ~amount ~fee |> Errors.Lift.sql )
        ; lift = Deferred.return
        }
  end

  module Impl (M : Monad_fail.S) = struct

    (* HACK: Sometimes we get bad nonce submit errors but they're really
     * duplicates. The daemon doesn't store enough information to tell the
     * difference. In order to disambiguate, we'll keep a cache of recent 100
     * successfully submitted transactions here. *)
    module Cache = struct
      (* Since size is just 100, we can just linearly scan an array to find
       * hits. *)
      let size = 100

      type t = { buf : Transaction.Signed.t option array; mutable idx : int }

      let create () =
        { buf = Array.init size ~f:(fun _i -> None)
        ; idx = 0
        }

      let add t txn =
        t.buf.(t.idx) <- Some txn;
        t.idx <- ((t.idx + 1) mod size)

      let find t txn =
        Array.find t.buf ~f:(fun x -> [%equal: Transaction.Signed.t option] (Some txn) x)

      let mem t txn =
        Option.is_some (find t txn)
    end

    let submitted_cache = lazy (Cache.create ())

    let handle
        ~(env :
           ( 'gql_payment
           , 'gql_delegation
           , 'gql_create_token
           , 'gql_create_token_account
           , 'gql_mint_tokens )
           Env.T(M).t) (req : Construction_submit_request.t) =
      let open M.Let_syntax in
      let%bind json =
        try M.return (Yojson.Safe.from_string req.signed_transaction)
        with _ -> M.fail (Errors.create (`Json_parse None))
      in
      let%bind signed_transaction =
        Transaction.Signed.Rendered.of_yojson json
        |> Result.map_error ~f:(fun e -> Errors.create (`Json_parse (Some e)))
        |> env.lift
      in
      let%bind txn =
        Transaction.Signed.of_rendered signed_transaction
        |> env.lift
      in
      let%map hash =
        match
          ( signed_transaction.payment
          , signed_transaction.stake_delegation
)
        with
        | Some payment, None->
            (
            match%bind
            env.gql_payment ~payment ~signature:signed_transaction.signature
              ()
            with
            | `Successful res ->
               let cache = Lazy.force submitted_cache in
               Cache.add cache txn;
               M.return res.Send_payment.sendPayment.payment.hash
            | `Failed e ->
               let cache = Lazy.force submitted_cache in
               if
                 ([%equal: Errors.Variant.t] (Errors.kind e) `Transaction_submit_bad_nonce) &&
                   Cache.mem cache txn
               then
                 M.fail (Errors.create `Transaction_submit_duplicate)
               else
                 (
                 let cmd = txn.command in
                 match%bind
                   env.db_transaction_exists
                     ~nonce:txn.nonce
                     ~source:(let (`Pk s) = cmd.source in s)
                     ~receiver:(let (`Pk r) = cmd.receiver in r)
                     ~amount:
                        (Option.value
                          ~default:Unsigned_extended.UInt64.zero cmd.amount)
                     ~fee:cmd.fee
                 with
                 | true ->
                   M.fail (Errors.create `Transaction_submit_duplicate)
                 | false ->
                   M.fail e ) )
        | None, Some delegation->
            let%map res =
              env.gql_delegation ~delegation
                ~signature:signed_transaction.signature ()
            in
            res.Send_delegation.sendDelegation.delegation.hash
        | _ ->
            M.fail
              (Errors.create
                 ~context:
                   "Must have one of payment, stakeDelegation"
                 (`Json_parse None))
      in
      Transaction_identifier_response.create
        (Transaction_identifier.create hash)
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

let router
  ~get_graphql_uri_or_error ~(with_db:(db:(module Caqti_async.CONNECTION) ->
 (Yojson.Safe.t, [> `App of Errors.t ]) Deferred.Result.t) ->
('a, [> `Page_not_found ]) Deferred.Result.t)
 ~logger
  (route : string list) body =
  [%log debug] "Handling /construction/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  let open Deferred.Result.Let_syntax in
  [%log info] "Construction query" ~metadata:[("query",body)];
  match route with
  | [ "derive" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_derive_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Derive.Real.handle ~env:Derive.Env.real req |> Errors.Lift.wrap
      in
      Construction_derive_response.to_yojson res
  | [ "preprocess" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_preprocess_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Preprocess.Real.handle ~env:Preprocess.Env.real req |> Errors.Lift.wrap
      in
      Construction_preprocess_response.to_yojson res
  | [ "metadata" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_metadata_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%bind graphql_uri = get_graphql_uri_or_error () in
      let%map res =
        Metadata.Real.handle ~graphql_uri
          ~env:(Metadata.Env.real ~graphql_uri)
          req
        |> Errors.Lift.wrap
      in
      Construction_metadata_response.to_yojson res
  | [ "payloads" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_payloads_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Payloads.Real.handle ~env:Payloads.Env.real req |> Errors.Lift.wrap
      in
      Construction_payloads_response.to_yojson res
  | [ "combine" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_combine_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Combine.Real.handle ~env:Combine.Env.real req |> Errors.Lift.wrap
      in
      Construction_combine_response.to_yojson res
  | [ "parse" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_parse_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Parse.Real.handle ~env:Parse.Env.real req |> Errors.Lift.wrap
      in
      Construction_parse_response.to_yojson res
  | [ "hash" ] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_hash_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Hash.Real.handle ~env:Hash.Env.real req |> Errors.Lift.wrap
      in
      Transaction_identifier_response.to_yojson res
  | [ "submit" ] ->
    let%bind graphql_uri = get_graphql_uri_or_error () in
    with_db (fun ~db ->
        let%bind req =
          Errors.Lift.parse ~context:"Request"
          @@ Construction_submit_request.of_yojson body
          |> Errors.Lift.wrap
        in
        let%map res =
          Submit.Real.handle ~env:(Submit.Env.real ~db ~graphql_uri) req
          |> Errors.Lift.wrap
        in
        Transaction_identifier_response.to_yojson res)
  | _ ->
      Deferred.Result.fail `Page_not_found
