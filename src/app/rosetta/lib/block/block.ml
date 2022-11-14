open! Core_kernel
open Rosetta_lib
open Rosetta_models

let router ~graphql_uri ~logger ~with_db (route : string list) body =
  let open Async.Deferred.Result.Let_syntax in
  [%log debug] "Handling /block/ $route"
    ~metadata:[ ("route", `List (List.map route ~f:(fun s -> `String s))) ] ;
  [%log info] "Block query" ~metadata:[ ("query", body) ] ;
  match route with
  | [] | [ "" ] ->
      with_db (fun ~db ->
          let%bind req =
            Errors.Lift.parse ~context:"Request" @@ Block_request.of_yojson body
            |> Errors.Lift.wrap
          in
          let%map res =
            Specific.Real.handle ~graphql_uri
              ~env:(Specific.Env.real ~logger ~db ~graphql_uri)
              req
            |> Errors.Lift.wrap
          in
          Block_response.to_yojson res )
  (* Note: We do not need to implement /block/transaction endpoint because we
   * don't return any "other_transactions" *)
  | _ ->
      Deferred.Result.fail `Page_not_found
