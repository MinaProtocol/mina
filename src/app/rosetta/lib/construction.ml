open Core_kernel
open Async
open Models
module Public_key = Signature_lib.Public_key

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
  | _ ->
      Deferred.Result.fail `Page_not_found
