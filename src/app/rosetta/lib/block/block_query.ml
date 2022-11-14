open Core_kernel
open Rosetta_lib
open Rosetta_models

type t = ([ `Height of int64 ], [ `Hash of string ]) These.t option

module T (M : Monad_fail.S) = struct
  let of_partial_identifier (identifier : Partial_block_identifier.t) =
    match (identifier.index, identifier.hash) with
    | None, None ->
        M.return None
    | Some index, None ->
        M.return (Some (`This (`Height index)))
    | None, Some hash ->
        M.return (Some (`That (`Hash hash)))
    | Some index, Some hash ->
        M.return (Some (`Those (`Height index, `Hash hash)))

  let of_partial_identifier' (identifier : Partial_block_identifier.t option) =
    of_partial_identifier
      (Option.value identifier
         ~default:{ Partial_block_identifier.index = None; hash = None } )

  let is_genesis ~hash ~block_height = function
    | Some (`This (`Height index)) ->
        Int64.equal index block_height
    | Some (`That (`Hash hash')) ->
        String.equal hash hash'
    | Some (`Those (`Height index, `Hash hash')) ->
        Int64.equal index block_height && String.equal hash hash'
    | None ->
        false
end

let to_string : t -> string = function
  | Some (`This (`Height h)) ->
      sprintf "height = %Ld" h
  | Some (`That (`Hash h)) ->
      sprintf "hash = %s" h
  | Some (`Those (`Height height, `Hash hash)) ->
      sprintf "height = %Ld, hash = %s" height hash
  | None ->
      sprintf "(no height or hash given)"
