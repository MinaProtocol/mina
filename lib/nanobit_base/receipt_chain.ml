open Core
open Util
open Snark_params
open Tick
open Let_syntax

module Hash = Data_hash.Make_full_size_strict_unpacking ()

module Entry = struct
  (* TODO: Consider only having the height instead of the full state hash *)
  type t = Blockchain_state.t * Transaction.Payload.t

  type var = Blockchain_state.var * Transaction.Payload.var

  let typ : (var, t) Typ.t =
    Typ.(Blockchain_state.typ * Transaction.Payload.typ)

  let fold (s, t) = Blockchain_state.fold s +> Transaction.Payload.fold t
end

(* TODO: Consider optimizing [Data_hash] in the following way.
  Have "Data_hash" and "Data_digest". Data_digest is what Data_hash is now.
  Data_hash caches the whole curve point for whatever subset of bits one
  hashes the value into. *)

type t = {entries: Entry.t list; base: Hash.t}

module Tail = struct
  include Hash

  let cons entry tail =
    Pedersen.digest_fold Hash_prefix.receipt_chain
      (Entry.fold entry +> fold tail)
    |> of_hash

  let empty =
    of_hash
      (Pedersen.(State.salt params "CodaReceiptEmpty") |> Pedersen.State.digest)

  module Checked = struct
    let empty = var_of_t empty

    let cons ~prefix_and_state ~payload_bits t =
      let%bind bits = var_to_bits t in
      let%map h =
        Tick.Pedersen_hash.hash ~params:Pedersen.params
          ~init:
            ( Blockchain_state.length_in_bits + Hash_prefix.length_in_bits
            , prefix_and_state )
          (payload_bits @ bits)
      in
      var_of_hash_packed (Tick.Pedersen_hash.digest h)
  end
end
