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
  type t =
    { sender : Public_key.Compressed.t
    }

  let to_json t =
    `Assoc [("sender", `String Public_key.Compressed.to_base58_check t.sender)]

  let of_json = function
    | `Assoc [("sender", `String pk)] -> Public_key.Compressed.of_base58_check pk |> Result.map_error ~f:(fun e -> Errors.create ~context:"Options of_json" (`Json_parse (Some (Core_kernel.Error.to_string_hum e))))
    | _ -> Result.fail @@ Errors.create ~context:"Options of_json expected {sender: string, token_id: stringified-number }" (`Json_parse None)
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
      ; metadata= None }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

module Metadata = struct
  module Env = struct
    module T (M : Monad_fail.S) = struct
      type 'gql t =
        { gql:
            ?token_id:string -> address:string -> unit -> ('gql, Errors.t) M.t
        ; validate_network_choice: 'gql Network.Validate_choice.Impl(M).t
        ; lift : ('a, 'e) Result.t -> ('a, 'e) M.t
        }
    end

    module Real = T (Deferred.Result)
    module Mock = T (Result)

    let real : graphql_uri:Uri.t -> 'gql Real.t =
      fun ~graphql_uri ->
      { gql=
          (fun ?token_id ~address () ->
             Graphql.query
               (Get_nonce.make ~public_key:(`String address)
                  ~token_id:
                    (match token_id with Some s -> `String s | None -> `Null)
                  ())
               graphql_uri )
      ; validate_network_choice= Network.Validate_choice.Real.validate
      ; lift = Deferred.return
      }
  end

  module Impl (M : Monad_fail.S) = struct
    let handle ~(env : Env.T(M).t) (req : Construction_metadata_request.t) =
      let open M.Let_syntax in
      let%bind options = Options.of_json req.options |> env.lift in
      let%bind res =
        env.gql
          ?token_id:(Option.map token_id ~f:Unsigned.UInt64.to_string)
          ~address ()
      in
      let%bind () =
        env.validate_network_choice ~network_identifier:req.network_identifier
          ~gql_response:res
      in
      let%bind account =
        match res#account with
        | None ->
          M.fail (Errors.create (`Account_not_found address))
        | Some account ->
          M.return account
      in

      (* TODO: Verify curve-type is tweedle *)
      let%map pk =
        Public_key.Hex.decode req.public_key.hex_bytes
        |> Result.map_error ~f:(fun _ -> Errors.create `Malformed_public_key)
        |> env.lift
      in
      { Construction_derive_response.address=
          Public_key.(compress pk |> Compressed.to_base58_check)
      ; metadata= None }
  end

  module Real = Impl (Deferred.Result)
  module Mock = Impl (Result)
end

let router ~graphql_uri:_ ~logger (route : string list) body =
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
      Metadata.Real.handle ~env:Metadata.Env.real req |> Errors.Lift.wrap
    in
    Construction_metadata_response.to_yojson res
  | _ ->
    Deferred.Result.fail `Page_not_found
