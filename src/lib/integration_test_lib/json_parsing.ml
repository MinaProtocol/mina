open Core_kernel
open Yojson.Safe.Util
open Mina_base

type 'a parser = Yojson.Safe.t -> 'a

let json : Yojson.Safe.t parser = Fn.id

let bool : bool parser = to_bool

let string : string parser = to_string

let int : int parser =
 fun x -> try to_int x with Type_error _ -> int_of_string (to_string x)

let float : float parser =
 fun x -> try to_float x with Type_error _ -> float_of_string (to_string x)

let list : 'a parser -> 'a list parser = fun f x -> List.map ~f (to_list x)

let state_hash : State_hash.t parser =
  Fn.compose Result.ok_or_failwith State_hash.of_yojson

let parse (parser : 'a parser) (json : Yojson.Safe.t) : 'a Or_error.t =
  try Ok (parser json)
  with exn ->
    Or_error.errorf "failed to parse json value: %s" (Exn.to_string exn)

let parser_from_of_yojson of_yojson js =
  match of_yojson js with
  | Ok cmd ->
      cmd
  | Error modl ->
      let logger = Logger.create () in
      [%log error] "Could not parse JSON using of_yojson"
        ~metadata:[ ("module", `String modl); ("json", js) ] ;
      failwithf "Could not parse JSON using %s.of_yojson" modl ()

let valid_commands_with_statuses :
    Mina_base.User_command.Valid.t Mina_base.With_status.t list parser =
  function
  | `List cmds ->
      let cmd_or_errors =
        List.map cmds
          ~f:
            (Mina_base.With_status.of_yojson
               Mina_base.User_command.Valid.of_yojson )
      in
      List.fold cmd_or_errors ~init:[] ~f:(fun accum cmd_or_err ->
          match (accum, cmd_or_err) with
          | _, Error err ->
              let logger = Logger.create () in
              [%log error]
                ~metadata:[ ("error", `String err) ]
                "Failed to parse JSON for user command status" ;
              (* fail on any error *)
              failwith
                "valid_commands_with_statuses: unable to parse JSON for user \
                 command"
          | cmds, Ok cmd ->
              cmd :: cmds )
  | _ ->
      failwith "valid_commands_with_statuses: expected `List"

let rec find (parser : 'a parser) (json : Yojson.Safe.t) (path : string list) :
    'a Or_error.t =
  let open Or_error.Let_syntax in
  match (path, json) with
  | [], _ ->
      parse parser json
  | key :: path', `Assoc assoc ->
      let%bind entry =
        match List.Assoc.find assoc key ~equal:String.equal with
        | Some entry ->
            Ok entry
        | None ->
            Or_error.errorf
              "failed to find path using key '%s' in json object { %s }" key
              (String.concat ~sep:", "
                 (List.map assoc ~f:(fun (s, json) ->
                      sprintf "\"%s\":%s" s (Yojson.Safe.to_string json) ) ) )
      in
      find parser entry path'
  | _ ->
      Or_error.error_string "expected json object when searching for path"
