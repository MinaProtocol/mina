open Core

exception Invalid of (string * Yojson.t) list

module Keyset = Stdlib.Set.Make(String)

module Error = struct
  type t = Unexpected_json of string * Yojson.t
         | Missing_key of string * Yojson.t
         | Missing_index of int * Yojson.t
         | Excessive_keys of string list * Yojson.t
         | Core_error of Error.t * Yojson.t
         | Exn of exn * Yojson.t

  let wrap_exn json e = Exn (e, json)
  let wrap_core_error json e = Core_error (e, json)

  let to_string = function
    | Unexpected_json (exp, json) ->
       Printf.sprintf "Invalid JSON: %s was expected (%s)." exp (Yojson.to_string json)
    | Missing_key (key, json) ->
       Printf.sprintf "Key %s not found in object: %s." key (Yojson.to_string json)
    | Missing_index (index, json) ->
       Printf.sprintf "Index %d out of array's bounds: %s." index (Yojson.to_string json)
    | Excessive_keys (ks, json) ->
       Printf.sprintf "Object posesses excess keys: %s (%s)."
         (String.concat ~sep:", " ks)
         (Yojson.to_string json)
    | Core_error (e, json) ->
       Printf.sprintf "Core error: %s (%s.)" (Error.to_string_hum e) (Yojson.to_string json)
    | Exn (e, json) ->
       Printf.sprintf "Exception thrown: %s (%s)." (Exn.to_string e) (Yojson.to_string json)

  let to_exn es =
    Invalid (
        List.map es ~f:(function
            | Unexpected_json (exp, json) ->
               (Printf.sprintf "Invalid JSON: %s was expected." exp, json)
            | Missing_key (key, json) ->
               (Printf.sprintf "Key %s not found in object." key, json)
            | Missing_index (index, json) ->
               (Printf.sprintf "Index %d out of array's bounds." index, json)
            | Excessive_keys (ks, json) ->
               (Printf.sprintf "Excess keys in object: %s." (String.concat ~sep:", " ks), json)
            | Core_error (e, json) ->
               (Printf.sprintf "Core error: %s" (Error.to_string_hum e), json)
            | Exn (e, json) ->
               (Printf.sprintf "Exception thrown: %s." (Exn.to_string e), json)))
end

module Validation = struct
  module T = struct
    include Rosetta_lib.Validation.T

    let bind = Result.bind
  end

  include T 
  include Monad.Make2(T)

  let map_m ~f l =
    let open Let_syntax in
    let rec map acc = function
      | [] -> return @@ List.rev acc
      | (x :: xs) ->
         let%bind y = f x in
         map (y :: acc) xs
    in
    map [] l
end

type 'a validation = ('a, Error.t list) Result.t

module Expect = struct
  module V = Validation

  let exn j e = V.fail @@ Error.Exn (e, j)
  let unexpected j expected = V.fail @@ Error.Unexpected_json (expected, j)

  let expected_option =
    let open Error in
    List.map ~f:(function
        | Unexpected_json (exp, json) ->
           Unexpected_json (exp ^ " option", json)
        | e -> e)
  
  let int = function
    | `Int i -> V.return i
    | `Intlit s as j ->
       (try V.return (Int.of_string s) with
       | e -> exn j e)
    | #Yojson.t as j -> unexpected j "int"

  let int64 = function
    | `Int i -> V.return @@ Int64.of_int i
    | `Intlit s as j ->
       (try V.return (Int64.of_string s) with
       | e -> exn j e)
    | #Yojson.t as j -> unexpected j "int64"

  let float = function
    | `Float f -> V.return f
    | `Floatlit s -> V.return (Float.of_string s)
    | #Yojson.t as j -> unexpected j "float"

  let string = function
    | `String s -> V.return s
    | `Stringlit s as j ->
       let open V.Let_syntax in
       let error = [Error.Unexpected_json ("string", j)] in
       let%bind suff =
         String.chop_prefix s ~prefix:"\"" |> Result.of_option ~error
       in
       String.chop_suffix suff ~suffix:"\"" |> Result.of_option ~error
    | #Yojson.t as j -> unexpected j "string"

  let list = function
    | `List l
    | `Tuple l -> V.return l
    | #Yojson.t as j -> unexpected j "list"

  let obj = function
    | `Assoc kvs -> V.return kvs
    | #Yojson.t as j -> unexpected j "object"

  let option expect = function
    | `Null -> V.return None
    | #Yojson.t as j ->
       expect j
       |> Result.map_error ~f:expected_option
       |> Result.map ~f:Option.some
end

let get key json =
  let open Validation.Let_syntax in
  let%bind kvs = Expect.obj json in
  List.Assoc.find ~equal:String.equal kvs key
  |> Result.of_option ~error:[Error.Missing_key (key, json)]

let index i json =
  let open Validation.Let_syntax in
  let%bind js = Expect.list json in
  List.nth js i
  |> Result.of_option ~error:[Error.Missing_index (i, json)]

(* We only need to check that the object does not have excess keys. Missing
   keys will be checked by extracting required data. *)
let assert_no_excess_keys ~keys json =
  let open Validation.Let_syntax in
  let%bind kvs = Expect.obj json in
  let excess = Keyset.(diff (of_list @@ List.map ~f:fst kvs) (of_list keys)) in
  if Keyset.is_empty excess then
    return ()
  else
    let l = Keyset.fold List.cons excess [] in
    Validation.fail @@ Error.Excessive_keys (l, json)
