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
