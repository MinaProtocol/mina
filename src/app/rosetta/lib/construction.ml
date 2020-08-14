open Core_kernel
open Async
open Models
module Public_key = Signature_lib.Public_key

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

module Metadata_data = struct
  let create ~nonce ~sender ~token_id =
    `Assoc
      [ ("sender", `String (Public_key.Compressed.to_base58_check sender))
      ; ("nonce", `String nonce)
      ; ("token_id", `String (Unsigned.UInt64.to_string token_id)) ]
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
          ~f:(fun nonce ->
            Unsigned.UInt64.(of_string nonce |> add one |> to_string) )
          account#nonce
        |> Option.value ~default:"1"
      in
      { Construction_metadata_response.metadata=
          Metadata_data.create ~sender:options.Options.sender
            ~token_id:options.Options.token_id ~nonce }
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
  | _ ->
      Deferred.Result.fail `Page_not_found
