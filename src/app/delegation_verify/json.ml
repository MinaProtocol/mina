open Core

let assoc_pop ~equal key assoc =
  let rec pop acc = function
    | [] ->
        None
    | (k, v) :: kvs when equal k key ->
        Some (v, List.rev_append acc kvs)
    | pair :: kvs ->
        pop (pair :: acc) kvs
  in
  pop [] assoc

let is_empty = function [] -> true | _ -> false

let assoc_replace_many ~equal replacements assoc =
  let rec replace acc us = function
    | [] ->
        List.rev acc
    | _ :: _ as kvs when is_empty us ->
        List.rev_append acc kvs
    | (k, v) :: kvs -> (
        match assoc_pop ~equal k us with
        | None ->
            replace ((k, v) :: acc) us kvs
        | Some (v', us') ->
            replace ((k, v') :: acc) us' kvs )
  in
  replace [] replacements assoc

let json_update updates = function
  | `Assoc obj ->
      `Assoc (assoc_replace_many ~equal:String.equal updates obj)
  | json ->
      raise (Yojson.Safe.Util.Type_error ("Expected object", json))
