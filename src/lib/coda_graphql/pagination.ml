open Core
open Async
open Graphql_async
open Schema
open Coda_base
open Auxiliary_database

module Page_info = struct
  type t =
    { has_previous_page: bool
    ; has_next_page: bool
    ; first_cursor: string option
    ; last_cursor: string option }

  let obj =
    obj "PageInfo"
      ~doc:"PageInfo object as described by the Relay connections spec"
      ~fields:(fun _ ->
        [ field "hasPreviousPage" ~typ:(non_null bool)
            ~args:Arg.[]
            ~resolve:(fun _ {has_previous_page; _} -> has_previous_page)
        ; field "hasNextPage" ~typ:(non_null bool)
            ~args:Arg.[]
            ~resolve:(fun _ {has_next_page; _} -> has_next_page)
        ; field "firstCursor" ~typ:string
            ~args:Arg.[]
            ~resolve:(fun _ {first_cursor; _} -> first_cursor)
        ; field "lastCursor" ~typ:string
            ~args:Arg.[]
            ~resolve:(fun _ {last_cursor; _} -> last_cursor) ] )
end

module Edge = struct
  type 'a t = {node: 'a; cursor: string}
end

module Connection = struct
  type 'a t = {edges: 'a Edge.t list; total_count: int; page_info: Page_info.t}
end

module type Inputs_intf = sig
  module Type : sig
    type t

    (** Representative type in the GraphQL API. This may be an [abstract_value]
        if the [typ] below is an interface instead of a direct declaration.
    *)
    type repr

    val conv : t -> repr

    val typ : (Coda_lib.t, repr option) typ

    val name : string
  end

  module Cursor : sig
    type t

    val serialize : t -> string

    val deserialize : ?error:string -> string -> (t, string) result

    val doc : string
  end

  module Pagination_database :
    Intf.Pagination
    with type value := Type.t
     and type cursor := Cursor.t
     and type time := Block_time.Time.Stable.V1.t

  val get_database : Coda_lib.t -> Pagination_database.t

  val filter_argument : Account.key option Schema.Arg.arg_typ

  val query_name : string

  val to_cursor : Type.t -> Cursor.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let edge : (Coda_lib.t, Type.t Edge.t option) typ =
    obj (Type.name ^ "Edge")
      ~doc:"Connection Edge as described by the Relay connections spec"
      ~fields:(fun _ ->
        [ field "cursor" ~typ:(non_null string) ~doc:Cursor.doc
            ~args:Arg.[]
            ~resolve:(fun _ {Edge.cursor; _} -> cursor)
        ; field "node" ~typ:(non_null Type.typ)
            ~args:Arg.[]
            ~resolve:(fun _ {Edge.node; _} -> Type.conv node) ] )

  let connection : (Coda_lib.t, Type.t Connection.t option) typ =
    obj (Type.name ^ "Connection")
      ~doc:"Connection as described by the Relay connections spec"
      ~fields:(fun _ ->
        [ field "edges"
            ~typ:(non_null @@ list @@ non_null edge)
            ~args:Arg.[]
            ~resolve:(fun _ {Connection.edges; _} -> edges)
        ; field "nodes"
            ~typ:(non_null @@ list @@ non_null Type.typ)
            ~args:Arg.[]
            ~resolve:(fun _ {Connection.edges; _} ->
              List.map edges ~f:(fun {Edge.node; _} -> Type.conv node) )
        ; field "totalCount" ~typ:(non_null int)
            ~args:Arg.[]
            ~resolve:(fun _ {Connection.total_count; _} -> total_count)
        ; field "pageInfo" ~typ:(non_null Page_info.obj)
            ~args:Arg.[]
            ~resolve:(fun _ {Connection.page_info; _} -> page_info) ] )

  let build_connection
      ( queried_transactions
      , `Has_earlier_page has_previous_page
      , `Has_later_page has_next_page ) total_count =
    let first_cursor =
      Option.map ~f:(fun {Edge.cursor; _} -> cursor)
      @@ List.hd queried_transactions
    in
    let last_cursor =
      Option.map ~f:(fun {Edge.cursor; _} -> cursor)
      @@ List.last queried_transactions
    in
    let page_info =
      {Page_info.has_previous_page; has_next_page; first_cursor; last_cursor}
    in
    {Connection.edges= queried_transactions; page_info; total_count}

  let query =
    io_field query_name
      ~args:
        Arg.
          [ arg "filter" ~typ:filter_argument
          ; arg "first" ~doc:"Returns the first _n_ elements from the list"
              ~typ:int
          ; arg "after"
              ~doc:
                "Returns the elements in the list that come after the \
                 specified cursor"
              ~typ:string
          ; arg "last" ~doc:"Returns the last _n_ elements from the list"
              ~typ:int
          ; arg "before"
              ~doc:
                "Returns the elements in the list that come before the \
                 specified cursor"
              ~typ:string ]
      ~typ:(non_null connection)
      ~resolve:(fun {ctx= coda; _} () public_key first after last before ->
        let open Deferred.Result.Let_syntax in
        let%map result, total_counts =
          let database = get_database coda in
          let resolve_cursor = function
            | None ->
                Ok None
            | Some data ->
                let open Result.Let_syntax in
                let%map decoded = Cursor.deserialize data in
                Some decoded
          in
          let account_id =
            (* TODO: Support multiple tokens. *)
            Option.map public_key ~f:(fun public_key ->
                Account_id.create public_key Token_id.default )
          in
          let value_filter_specification =
            Option.value_map account_id ~default:`All ~f:(fun account_id ->
                `User_only account_id )
          in
          let%map ( (queried_nodes, has_earlier_page, has_later_page)
                  , total_counts ) =
            Deferred.return
            @@
            match (first, after, last, before) with
            | Some _n_queries_before, _, Some _n_queries_after, _ ->
                Error
                  "Illegal query: first and last must not be non-null value \
                   at the same time"
            | num_items, cursor, None, _ ->
                let open Result.Let_syntax in
                let%map cursor = resolve_cursor cursor in
                ( Pagination_database.query database ~navigation:`Earlier
                    ~value_filter_specification ~cursor ~num_items
                , Pagination_database.get_total_values database account_id )
            | None, _, num_items, cursor ->
                let open Result.Let_syntax in
                let%map cursor = resolve_cursor cursor in
                ( Pagination_database.query database ~navigation:`Later
                    ~value_filter_specification ~cursor ~num_items
                , Pagination_database.get_total_values database account_id )
          in
          ( ( List.map queried_nodes ~f:(fun node ->
                  {Edge.node; cursor= Cursor.serialize @@ to_cursor node} )
            , has_earlier_page
            , has_later_page )
          , Option.value ~default:0 total_counts )
        in
        build_connection result total_counts )
end
