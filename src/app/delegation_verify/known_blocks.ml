open Async
open Core

module Block_hash = struct
  open Sexplib.Conv

  type t = string [@@deriving sexp, compare]

  let hash = Base.String.hash
end

module Deferred_block = struct
  type t =
    { block : Mina_block.t Deferred.Or_error.t
    ; valid : unit Deferred.Or_error.t (* Raises if block is invalid. *)
    }

  let block_of_string contents =
    let compute v =
      let r =
        try Ok (Binable.of_string (module Mina_block.Stable.Latest) contents)
        with _ -> Error (Error.of_string "Fail to decode block")
      in
      Async.Ivar.fill v r
    in
    Deferred.create compute

  let verify_block ~verify_blockchain_snarks block =
    let header = Mina_block.header block in
    let open Mina_block.Header in
    verify_blockchain_snarks
      [ (protocol_state header, protocol_state_proof header) ]

  let create ?(validate = true) ~verify_blockchain_snarks contents =
    let open Deferred.Or_error.Monad_infix in
    let block = contents >>= block_of_string in
    let valid =
      if validate then block >>= verify_block ~verify_blockchain_snarks
      else Deferred.Or_error.return ()
    in
    { block; valid }
end

let known_blocks : (Block_hash.t, Deferred_block.t) Hashtbl.t =
  Hashtbl.create (module Block_hash)

let add ?validate ~verify_blockchain_snarks ~block_hash block_contents =
  let block =
    Deferred_block.create ?validate ~verify_blockchain_snarks block_contents
  in
  Hashtbl.add_exn known_blocks ~key:block_hash ~data:block

let is_known hash = Hashtbl.mem known_blocks hash

let get hash =
  match Hashtbl.find known_blocks hash with
  | None ->
      Deferred.Or_error.errorf "Block %s not found" hash
  | Some b ->
      b.block

let is_valid hash =
  match Hashtbl.find known_blocks hash with
  | None ->
      Deferred.Or_error.errorf "Block %s not found" hash
  | Some b ->
      b.valid
