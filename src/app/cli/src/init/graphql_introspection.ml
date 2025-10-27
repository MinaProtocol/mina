open Core
open Async

let get_field_names schema ctx type_name =
  let open Deferred.Let_syntax in
  let introspection_query_raw =
    Printf.sprintf
      {graphql|
query {
  __schema {
    types {
      name
      fields {
        name
      }
    }
  }
}
|graphql}
  in
  let%bind introspection_query =
    match Graphql_parser.parse introspection_query_raw with
    | Ok res ->
        return res
    | Error err ->
        failwith err
  in
  let%bind res = Graphql_async.Schema.execute schema ctx introspection_query in
  match res with
  | Ok (`Response data) -> (
      match Yojson.Basic.Util.(member "__schema" (member "data" data)) with
      | `Assoc schema_data -> (
          match List.Assoc.find schema_data ~equal:String.equal "types" with
          | Some (`List types) -> (
              match
                List.find types ~f:(fun t ->
                    match
                      Yojson.Basic.Util.(to_string_option (member "name" t))
                    with
                    | Some name ->
                        String.equal name type_name
                    | None ->
                        false )
              with
              | Some type_obj -> (
                  match
                    Yojson.Basic.Util.(to_option (member "fields") type_obj)
                  with
                  | Some (`List fields) ->
                      return
                        (List.filter_map fields ~f:(fun field ->
                             Yojson.Basic.Util.(
                               to_string_option (member "name" field)) ) )
                  | _ ->
                      return [] )
              | None ->
                  return [] )
          | _ ->
              return [] )
      | _ ->
          return [] )
  | _ ->
      return []

let list_cmd =
  Command.async ~summary:"List all available GraphQL endpoints"
    (let%map.Command () = Command.Param.return () in
     fun () ->
       let open Deferred.Let_syntax in
       Core.print_endline "Available GraphQL endpoints:\n" ;
       (* Main endpoint *)
       Core.print_endline
         "  main       - Full GraphQL API (default port: 3085, \
          --rest-server-port)" ;
       let%bind main_queries =
         get_field_names Mina_graphql.schema (Obj.magic ()) "query"
       in
       let%bind main_mutations =
         get_field_names Mina_graphql.schema (Obj.magic ()) "mutation"
       in
       let%bind main_subscriptions =
         get_field_names Mina_graphql.schema (Obj.magic ()) "subscription"
       in
       Core.print_endline
         (sprintf "    Queries (%d):" (List.length main_queries)) ;
       List.iter (List.sort ~compare:String.compare main_queries) ~f:(fun q ->
           Core.print_endline (sprintf "      - %s" q) ) ;
       Core.print_endline
         (sprintf "    Mutations (%d):" (List.length main_mutations)) ;
       List.iter (List.sort ~compare:String.compare main_mutations) ~f:(fun m ->
           Core.print_endline (sprintf "      - %s" m) ) ;
       Core.print_endline
         (sprintf "    Subscriptions (%d):" (List.length main_subscriptions)) ;
       List.iter (List.sort ~compare:String.compare main_subscriptions)
         ~f:(fun s -> Core.print_endline (sprintf "      - %s" s)) ;
       Core.print_endline
         "    Example: curl -s -X POST http://localhost:3085/graphql -H \
          'Content-Type: application/json' \\" ;
       Core.print_endline
         "             -d '{\"query\": \"{ daemonStatus { chainId \
          blockchainLength numAccounts } }\"}'\n" ;
       (* Limited endpoint *)
       Core.print_endline
         "  limited    - Limited GraphQL API (--limited-graphql-port)" ;
       let%bind limited_queries =
         get_field_names Mina_graphql.schema_limited (Obj.magic ()) "query"
       in
       Core.print_endline
         (sprintf "    Queries (%d):" (List.length limited_queries)) ;
       List.iter (List.sort ~compare:String.compare limited_queries)
         ~f:(fun q -> Core.print_endline (sprintf "      - %s" q)) ;
       ( match List.hd limited_queries with
       | Some first_query ->
           Core.print_endline
             (sprintf
                "    Example: curl -s -X POST \
                 http://localhost:<limited-port>/graphql -H 'Content-Type: \
                 application/json' \\" ) ;
           Core.print_endline
             (sprintf "             -d '{\"query\": \"{ %s }\"}'\n" first_query)
       | None ->
           Core.print_endline "" ) ;
       (* ITN endpoint *)
       Core.print_endline
         "  itn        - Incentivized Testnet GraphQL API (--itn-graphql-port, \
          requires ITN_FEATURES)" ;
       let%bind itn_queries =
         get_field_names Mina_graphql.schema_itn (Obj.magic (true, ())) "query"
       in
       let%bind itn_mutations =
         get_field_names Mina_graphql.schema_itn
           (Obj.magic (true, ()))
           "mutation"
       in
       Core.print_endline
         (sprintf "    Queries (%d):" (List.length itn_queries)) ;
       List.iter (List.sort ~compare:String.compare itn_queries) ~f:(fun q ->
           Core.print_endline (sprintf "      - %s" q) ) ;
       Core.print_endline
         (sprintf "    Mutations (%d):" (List.length itn_mutations)) ;
       List.iter (List.sort ~compare:String.compare itn_mutations) ~f:(fun m ->
           Core.print_endline (sprintf "      - %s" m) ) ;
       ( match List.hd itn_queries with
       | Some first_query ->
           Core.print_endline
             (sprintf
                "    Example: curl -s -X POST http://localhost:<itn-port>/graphql \
                 -H 'Content-Type: application/json' \\" ) ;
           Core.print_endline
             (sprintf "             -d '{\"query\": \"{ %s }\"}'\n" first_query)
       | None ->
           Core.print_endline "" ) ;
       Core.print_endline
         "Use 'mina internal graphql inspect [query]' to view details about a \
          specific query." ;
       return () )

let get_query_details schema ctx query_name =
  let open Deferred.Let_syntax in
  let introspection_query_raw =
    {graphql|
query {
  __schema {
    types {
      name
      fields {
        name
        description
        args {
          name
          description
          type {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
              }
            }
          }
        }
        type {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
            }
          }
        }
      }
    }
  }
}
|graphql}
  in
  let%bind introspection_query =
    match Graphql_parser.parse introspection_query_raw with
    | Ok res ->
        return res
    | Error err ->
        failwith err
  in
  let%bind res = Graphql_async.Schema.execute schema ctx introspection_query in
  match res with
  | Ok (`Response data) -> (
      match Yojson.Basic.Util.(member "__schema" (member "data" data)) with
      | `Assoc schema_data -> (
          match List.Assoc.find schema_data ~equal:String.equal "types" with
          | Some (`List types) -> (
              (* Find the Query type *)
              match
                List.find types ~f:(fun t ->
                    match
                      Yojson.Basic.Util.(to_string_option (member "name" t))
                    with
                    | Some name ->
                        String.equal name "query"
                    | None ->
                        false )
              with
              | Some query_type -> (
                  match
                    Yojson.Basic.Util.(to_option (member "fields") query_type)
                  with
                  | Some (`List fields) -> (
                      (* Find the specific query field *)
                      match
                        List.find fields ~f:(fun field ->
                            match
                              Yojson.Basic.Util.(
                                to_string_option (member "name" field))
                            with
                            | Some name ->
                                String.equal name query_name
                            | None ->
                                false )
                      with
                      | Some field ->
                          return (Some field)
                      | None ->
                          return None )
                  | _ ->
                      return None )
              | None ->
                  return None )
          | _ ->
              return None )
      | _ ->
          return None )
  | _ ->
      return None

let format_type json =
  let open Yojson.Basic.Util in
  let rec format_type_inner json =
    match member "kind" json |> to_string_option with
    | Some "NON_NULL" -> (
        match to_option (member "ofType") json with
        | Some ofType ->
            format_type_inner ofType ^ "!"
        | None ->
            "?" )
    | Some "LIST" -> (
        match to_option (member "ofType") json with
        | Some ofType ->
            "[" ^ format_type_inner ofType ^ "]"
        | None ->
            "[?]" )
    | Some _ | None -> (
        match to_string_option (member "name" json) with
        | Some name ->
            name
        | None ->
            "?" )
  in
  format_type_inner json

let format_arg arg =
  let open Yojson.Basic.Util in
  let name = to_string_option (member "name" arg) |> Option.value ~default:"?" in
  let type_json = member "type" arg in
  let type_str = format_type type_json in
  let desc =
    match to_string_option (member "description" arg) with
    | Some d ->
        sprintf " # %s" d
    | None ->
        ""
  in
  sprintf "  %s: %s%s" name type_str desc

let inspect_cmd =
  let open Command.Let_syntax in
  Command.async ~summary:"Inspect a specific GraphQL query"
    (let%map query_name = Command.Param.(anon ("query" %: string)) in
     fun () ->
       let open Deferred.Let_syntax in
       (* Search in all three schemas *)
       let%bind main_result =
         get_query_details Mina_graphql.schema (Obj.magic ()) query_name
       in
       let%bind limited_result =
         get_query_details Mina_graphql.schema_limited (Obj.magic ()) query_name
       in
       let%bind itn_result =
         get_query_details Mina_graphql.schema_itn
           (Obj.magic (true, ()))
           query_name
       in
       let found_any = ref false in
       Core.print_endline (sprintf "Query: %s\n" query_name) ;
       (* Display results for each endpoint *)
       ( match main_result with
       | Some field ->
           found_any := true ;
           Core.print_endline "Available in: main endpoint (port 3085)" ;
           let desc =
             match
               Yojson.Basic.Util.(to_string_option (member "description" field))
             with
             | Some d ->
                 sprintf "Description: %s\n" d
             | None ->
                 ""
           in
           Core.print_endline desc ;
           let type_json = Yojson.Basic.Util.(member "type" field) in
           Core.print_endline (sprintf "Returns: %s" (format_type type_json)) ;
           ( let args_json = Yojson.Basic.Util.(member "args" field) in
             match args_json with
             | `List args when List.length args > 0 ->
                 Core.print_endline "Arguments:" ;
                 List.iter args ~f:(fun arg ->
                     Core.print_endline (format_arg arg) )
             | _ ->
                 Core.print_endline "Arguments: none" ) ;
           Core.print_endline ""
       | None ->
           () ) ;
       ( match limited_result with
       | Some field ->
           found_any := true ;
           Core.print_endline "Available in: limited endpoint (--limited-graphql-port)" ;
           let desc =
             match
               Yojson.Basic.Util.(to_string_option (member "description" field))
             with
             | Some d ->
                 sprintf "Description: %s\n" d
             | None ->
                 ""
           in
           Core.print_endline desc ;
           let type_json = Yojson.Basic.Util.(member "type" field) in
           Core.print_endline (sprintf "Returns: %s" (format_type type_json)) ;
           ( let args_json = Yojson.Basic.Util.(member "args" field) in
             match args_json with
             | `List args when List.length args > 0 ->
                 Core.print_endline "Arguments:" ;
                 List.iter args ~f:(fun arg ->
                     Core.print_endline (format_arg arg) )
             | _ ->
                 Core.print_endline "Arguments: none" ) ;
           Core.print_endline ""
       | None ->
           () ) ;
       ( match itn_result with
       | Some field ->
           found_any := true ;
           Core.print_endline
             "Available in: itn endpoint (--itn-graphql-port, requires \
              ITN_FEATURES)" ;
           let desc =
             match
               Yojson.Basic.Util.(to_string_option (member "description" field))
             with
             | Some d ->
                 sprintf "Description: %s\n" d
             | None ->
                 ""
           in
           Core.print_endline desc ;
           let type_json = Yojson.Basic.Util.(member "type" field) in
           Core.print_endline (sprintf "Returns: %s" (format_type type_json)) ;
           ( let args_json = Yojson.Basic.Util.(member "args" field) in
             match args_json with
             | `List args when List.length args > 0 ->
                 Core.print_endline "Arguments:" ;
                 List.iter args ~f:(fun arg ->
                     Core.print_endline (format_arg arg) )
             | _ ->
                 Core.print_endline "Arguments: none" ) ;
           Core.print_endline ""
       | None ->
           () ) ;
       if not !found_any then
         failwithf "Query '%s' not found in any endpoint" query_name () ;
       return () )
