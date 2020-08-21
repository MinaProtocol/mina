open Core_kernel
open Async
open Models
module Public_key = Signature_lib.Public_key
module User_command_payload = Coda_base.User_command_payload
module User_command = Coda_base.User_command

module Get_nonce =
[%graphql
{|
    query get_nonce($public_key: PublicKey!, $token_id: TokenId) {
      account(publicKey: $public_key, token: $token_id) {
        balance {
          blockHeight @bsDecoder(fn: "Decoders.uint32")
          stateHash
        }
        nonce
      }
      daemonStatus {
        peers
      }
      initialPeers
     }
|}]

module Options = struct
  type t = {sender: Public_key.Compressed.t; token_id: Unsigned.UInt64.t}

  module Raw = struct
    type t = {sender: string; token_id: string} [@@deriving yojson]
  end

  let to_json t =
    { Raw.sender= Public_key.Compressed.to_base58_check t.sender
    ; token_id= Unsigned.UInt64.to_string t.token_id }
    |> Raw.to_yojson

  let of_json r =
    Raw.of_yojson r
    |> Result.map_error ~f:(fun e ->
           Errors.create ~context:"Options of_json" (`Json_parse (Some e)) )
    |> Result.bind ~f:(fun r ->
           let open Result.Let_syntax in
           let%map sender =
             Public_key.Compressed.of_base58_check r.sender
             |> Result.map_error ~f:(fun e ->
                    Errors.create ~context:"Options of_json bad public key"
                      (`Json_parse (Some (Core_kernel.Error.to_string_hum e)))
                )
           in
           {sender; token_id= Unsigned.UInt64.of_string r.token_id} )
end

(* TODO: unify handling of json between this and Options (above) and everything else in rosetta *)
module Metadata_data = struct
  type t =
    { sender: string
    ; nonce: Unsigned_extended.UInt32.t
    ; token_id: Unsigned_extended.UInt64.t }
  [@@deriving yojson]

  let create ~nonce ~sender ~token_id =
    {sender= Public_key.Compressed.to_base58_check sender; nonce; token_id}

  let of_json r =
    of_yojson r
    |> Result.map_error ~f:(fun e ->
           Errors.create ~context:"Options of_json" (`Json_parse (Some e)) )
end

module Derive = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = {lift: 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t}
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = {lift= Deferred.return}

    let mock : Mock.t = {lift= Fn.id}
  end

  module Impl (M : Monad_fail.S) = struct
    (* TODO: Don't assume req.metadata is a token_id without checking *)
    let handle ~(env : Env.T(M).t) (req : Construction_derive_request.t) =
      let open M.Let_syntax in
      (* TODO: Verify curve-type is tweedle *)
      let%map pk =
        Public_key.Hex.decode req.public_key.hex_bytes
        |> Result.map_error ~f:(fun _ -> Errors.create `Malformed_public_key)
        |> env.lift
      in
      { Construction_derive_response.address=
          Public_key.(compress pk |> Compressed.to_base58_check)
      ; metadata= req.metadata }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Metadata = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql:
               ?token_id:Unsigned.UInt64.t
            -> address:Public_key.Compressed.t
            -> unit
            -> ('gql, Errors.t) M.t
        ; validate_network_choice: 'gql Network.Validate_choice.Impl(M).t
        ; lift: 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : graphql_uri:Uri.t -> 'gql Real.t =
     fun ~graphql_uri ->
      { gql=
          (fun ?token_id ~address () ->
            Graphql.query
              (Get_nonce.make
                 ~public_key:
                   (`String (Public_key.Compressed.to_base58_check address))
                 ~token_id:
                   ( match token_id with
                   | Some x ->
                       `String (Unsigned.UInt64.to_string x)
                   | None ->
                       `Null )
                 ())
              graphql_uri )
      ; validate_network_choice= Network.Validate_choice.Real.validate
      ; lift= Deferred.return }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : 'gql Env.T(M).t) (req : Construction_metadata_request.t)
        =
      let open M.Let_syntax in
      let%bind options = Options.of_json req.options |> env.lift in
      let%bind res =
        env.gql ~token_id:options.token_id ~address:options.sender ()
      in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      let%map account =
        match res#account with
        | None ->
            M.fail
              (Errors.create
                 (`Account_not_found
                   (Public_key.Compressed.to_base58_check options.sender)))
        | Some account ->
            M.return account
      in
      let nonce =
        Option.map
          ~f:(fun nonce -> Unsigned.UInt32.(of_string nonce |> add one))
          account#nonce
        |> Option.value ~default:Unsigned.UInt32.one
      in
      { Construction_metadata_response.metadata=
          Metadata_data.create ~sender:options.Options.sender
            ~token_id:options.Options.token_id ~nonce
          |> Metadata_data.to_yojson }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Preprocess = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = {lift: 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t}
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = {lift= Deferred.return}

    let mock : Mock.t = {lift= Fn.id}
  end

  module Impl (M : Monad_fail.S) = struct
    let lift_reason_validation_to_errors ~(env : Env.T(M).t) t =
      Result.map_error t ~f:(fun reasons ->
          Errors.create (`Operations_not_valid reasons) )
      |> env.lift

    let handle ~(env : Env.T(M).t) (req : Construction_preprocess_request.t) =
      let open M.Let_syntax in
      let%bind partial_user_command =
        User_command_info.of_operations req.operations
        |> lift_reason_validation_to_errors ~env
      in
      let%map pk =
        let (`Pk pk) = partial_user_command.User_command_info.Partial.source in
        Public_key.Compressed.of_base58_check pk
        |> Result.map_error ~f:(fun _ ->
               Errors.create `Public_key_format_not_valid )
        |> env.lift
      in
      { Construction_preprocess_response.options=
          Some
            (Options.to_json
               { Options.sender= pk
               ; token_id= partial_user_command.User_command_info.Partial.token
               }) }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Payloads = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = {lift: 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t}
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = {lift= Deferred.return}

    let mock : Mock.t = {lift= Fn.id}
  end

  module Impl (M : Monad_fail.S) = struct
    let lift_reason_validation_to_errors ~(env : Env.T(M).t) t =
      Result.map_error t ~f:(fun reasons ->
          Errors.create (`Operations_not_valid reasons) )
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
        User_command_info.of_operations req.operations
        |> lift_reason_validation_to_errors ~env
      in
      let%bind pk =
        let (`Pk pk) = partial_user_command.User_command_info.Partial.source in
        Public_key.Compressed.of_base58_check pk
        |> Result.map_error ~f:(fun _ ->
               Errors.create ~context:"compression"
                 `Public_key_format_not_valid )
        |> Result.bind ~f:(fun pk ->
               Result.of_option (Public_key.decompress pk)
                 ~error:
                   (Errors.create ~context:"decompression"
                      `Public_key_format_not_valid) )
        |> Result.map ~f:Public_key.Hex.encode
        |> env.lift
      in
      let%bind user_command_payload =
        User_command_info.Partial.to_user_command_payload ~nonce:metadata.nonce
          partial_user_command
        |> env.lift
      in
      let random_oracle_input = User_command.to_input user_command_payload in
      let%map unsigned_transaction_string =
        { Unsigned_transaction.random_oracle_input
        ; command= partial_user_command
        ; nonce= metadata.nonce }
        |> Unsigned_transaction.render
        |> Result.map ~f:Unsigned_transaction.Rendered.to_yojson
        |> Result.map ~f:Yojson.Safe.to_string
        |> env.lift
      in
      { Construction_payloads_response.unsigned_transaction=
          unsigned_transaction_string
      ; payloads=
          [ { Signing_payload.address=
                (let (`Pk pk) =
                   partial_user_command.User_command_info.Partial.source
                 in
                 pk)
            ; hex_bytes= pk
            ; signature_type= Some "schnorr" } ] }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Parse = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type t = {lift: 'a 'e. ('a, 'e) Result.t -> ('a, 'e) M.t}
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : Real.t = {lift= Deferred.return}

    let mock : Mock.t = {lift= Fn.id}
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : Env.T(M).t) (req : Construction_parse_request.t) =
      let open M.Let_syntax in
      let%bind json =
        try M.return (Yojson.Safe.from_string req.transaction)
        with _ -> M.fail (Errors.create (`Json_parse None))
      in
      let%map operations, `Pk signer_pk =
        match req.signed with
        | true ->
            let%map signed_transaction =
              Unsigned_transaction.Signed.Rendered.of_yojson json
              |> Result.map_error ~f:(fun e ->
                     Errors.create (`Json_parse (Some e)) )
              |> Result.bind ~f:Unsigned_transaction.Signed.of_rendered
              |> env.lift
            in
            ( User_command_info.to_operations ~failure_status:None
                signed_transaction.command
            , signed_transaction.command.source )
        | false ->
            let%map unsigned_transaction =
              Unsigned_transaction.Rendered.of_yojson json
              |> Result.map_error ~f:(fun e ->
                     Errors.create (`Json_parse (Some e)) )
              |> Result.bind ~f:Unsigned_transaction.of_rendered
              |> env.lift
            in
            ( User_command_info.to_operations ~failure_status:None
                unsigned_transaction.command
            , unsigned_transaction.command.source )
      in
      { Construction_parse_response.operations
      ; signers= [signer_pk]
      ; metadata= None }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

let router ~graphql_uri ~logger (route : string list) body =
  [%log debug] "Handling /construction/ $route"
    ~metadata:[("route", `List (List.map route ~f:(fun s -> `String s)))] ;
  let open Deferred.Result.Let_syntax in
  match route with
  | ["derive"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_derive_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Derive.Real.handle ~env:Derive.Env.real req |> Errors.Lift.wrap
      in
      Construction_derive_response.to_yojson res
  | ["preprocess"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_preprocess_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Preprocess.Real.handle ~env:Preprocess.Env.real req |> Errors.Lift.wrap
      in
      Construction_preprocess_response.to_yojson res
  | ["metadata"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_metadata_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Metadata.Real.handle ~env:(Metadata.Env.real ~graphql_uri) req
        |> Errors.Lift.wrap
      in
      Construction_metadata_response.to_yojson res
  | ["payloads"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_payloads_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Payloads.Real.handle ~env:Payloads.Env.real req |> Errors.Lift.wrap
      in
      Construction_payloads_response.to_yojson res
  | ["parse"] ->
      let%bind req =
        Errors.Lift.parse ~context:"Request"
        @@ Construction_parse_request.of_yojson body
        |> Errors.Lift.wrap
      in
      let%map res =
        Parse.Real.handle ~env:Parse.Env.real req |> Errors.Lift.wrap
      in
      Construction_parse_response.to_yojson res
  | _ ->
      Deferred.Result.fail `Page_not_found
