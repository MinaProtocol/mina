open Graphql_async.Schema

(** A module providing the typ value used to build the graphql schema as well as
    well as utility functions to build queries and parse responses.
 *)
module type TYP = sig
  type out

  (** [typ] value for the graphql schema *)
  val typ : unit -> (unit, out) typ

  type 'a query

  type 'a res

  val response_of_json : 'a query -> Yojson.Basic.t -> 'a res

  val mk_query : 'a query -> string
end

module Non_null (Aux : sig
  type new_out

  type 'a new_res
end)
(Input : TYP
           with type out = Aux.new_out option
            and type 'a res = 'a Aux.new_res option) :
  TYP
    with type out = Aux.new_out
     and type 'a query = 'a Input.query
     and type 'a res = 'a Aux.new_res = struct
  type out = Aux.new_out

  type 'a res = 'a Aux.new_res

  type 'a query = 'a Input.query

  let typ () = non_null @@ Input.typ ()

  let response_of_json query json =
    match Input.response_of_json query json with
    | None ->
        failwith @@ "Non nullable value should not return None " ^ __LOC__
    | Some v ->
        v

  let mk_query = Input.mk_query
end

module List (Input : TYP) :
  TYP
    with type out = Input.out list option
     and type 'a query = 'a Input.query
     and type 'a res = 'a Input.res list = struct
  type 'a res = 'a Input.res list

  type 'a query = 'a Input.query

  let response_of_json query json =
    match json with
    | `List l ->
        List.map (Input.response_of_json query) l
    | _ ->
        failwith
        @@ Format.asprintf "expecting a json list (%s): but got\n%a\n " __LOC__
             Yojson.Basic.pp json

  type out = Input.out list option

  let typ () = list @@ Input.typ ()

  let mk_query = Input.mk_query
end

type no_subquery

let non_null_list_of_json elem_of_json query json =
  match json with
  | `List l ->
      Stdlib.List.map (elem_of_json query) l
  | _ ->
      failwith
      @@ Format.asprintf "expecting a json list (%s): but got\n%a\n " __LOC__
           Yojson.Basic.pp json

let list_of_json elem_of_json query json =
  match json with
  | `Null ->
      None
  | json ->
      Some (non_null_list_of_json elem_of_json query json)
