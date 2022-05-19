let rec get key = function
  | `Assoc ((k, value) :: _) when k = key ->
      value
  | `Assoc (_ :: q) ->
      get key @@ `Assoc q
  | json ->
      failwith
      @@ Format.asprintf "key %s not found in json (%s)\n%s\n" key __LOC__
           (Yojson.Basic.to_string json)

let get_string = function
  | `String s ->
      s
  | json ->
      failwith
      @@ Format.asprintf "expecting a string as json argument (%s)\n%s\n"
           __LOC__
           (Yojson.Basic.to_string json)

let get_int = function
  | `Int i ->
      i
  | json ->
      failwith
      @@ Format.asprintf "expecting an int as json argument (%s)\n%s\n" __LOC__
           (Yojson.Basic.to_string json)

let string_of_option (f : 'a -> string) (x : 'a option) : string =
  match x with None -> "null" | Some x -> f x

let json_of_option (f : 'a -> Yojson.Basic.t) (x : 'a option) : Yojson.Basic.t =
  match x with None -> `Null | Some x -> f x

let non_null_list_of_json elem_of_json query json =
  match json with
  | `List l ->
      Stdlib.List.map (elem_of_json query) l
  | _ ->
      failwith
      @@ Format.asprintf "expecting a json list (%s): but got\n%a\n " __LOC__
           Yojson.Basic.pp json

let nullable of_json query json =
  match json with `Null -> None | json -> Some (of_json query json)

let list_of_json elem_of_json query json =
  nullable (non_null_list_of_json elem_of_json) query json

let fail_parsing kind json =
  failwith
  @@ Format.asprintf "expecting a %s when parsing json\n%s\n" kind
       (Yojson.Basic.to_string json)
