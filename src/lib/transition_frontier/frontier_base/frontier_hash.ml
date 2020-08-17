open Core_kernel
open Coda_base
open Coda_transition
open Signature_lib
open Digestif.SHA256

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type t = Digestif.SHA256.t

    let to_latest = Fn.id

    module Base58_check = Base58_check.Make (struct
      let description = "Frontier hash"

      let version_byte = Base58_check.Version_bytes.frontier_hash
    end)

    let to_yojson hash =
      [%derive.to_yojson: string] (Base58_check.encode (to_raw_string hash))

    let of_yojson json =
      let open Result.Let_syntax in
      let%bind raw_str = [%derive.of_yojson: string] json in
      let%bind str =
        Base58_check.decode raw_str |> Result.map_error ~f:Error.to_string_hum
      in
      match of_raw_string_opt str with
      | Some hash ->
          Ok hash
      | None ->
          Error "invalid raw hash"

    include Binable.Of_stringable (struct
      type nonrec t = t

      let of_string = of_hex

      let to_string = to_hex
    end)
  end
end]

[%%define_locally
Stable.Latest.(to_yojson, of_yojson)]

module Base58_check = Stable.Latest.Base58_check

type transition = {source: t; target: t}

let equal t1 t2 = equal t1 t2

let empty = digest_string ""

let merge_string t1 string = digestv_string [to_hex t1; string]

let to_string = to_hex

let merge_state_hash acc state_hash =
  merge_string acc (State_hash.raw_hash_bytes state_hash)

(* This currently only hashes the creator of the staged ledger
 * diff. The previous hash is already encapsulated in the
 * transition frontier incremental diff hash via the state
 * hash since the Blockchain_state contains the previous
 * staged ledger hash already. The only information missing
 * from this is the actual contents of the diff itself
 * (the transactions). This can't be included in O(1) as is
 * since it is not precomputed, so it is left out here for now. *)
let merge_staged_ledger_diff acc diff =
  (* TODO: hash target ledger hash? (does this need to be computed?) *)
  merge_string acc
    (Public_key.Compressed.to_string (Staged_ledger_diff.creator diff))

let merge_transition acc transition =
  merge_staged_ledger_diff
    (merge_state_hash acc (External_transition.Validated.state_hash transition))
    (External_transition.Validated.staged_ledger_diff transition)

let merge_pending_coinbase acc pending_coinbase =
  let root_hash = Pending_coinbase.merkle_root pending_coinbase in
  merge_string acc (Pending_coinbase.Hash.to_bytes root_hash)

let merge_scan_state acc scan_state =
  let hash = Staged_ledger.Scan_state.hash scan_state in
  merge_string acc (Staged_ledger_hash.Aux_hash.to_bytes hash)

let merge_protocol_states acc protocol_states =
  List.fold protocol_states ~init:acc ~f:(fun acc (h, _) ->
      merge_state_hash acc h )

let merge_root_data acc (root_data : Root_data.Limited.t) =
  let open Root_data.Limited in
  merge_protocol_states
    (merge_pending_coinbase
       (merge_scan_state
          (merge_state_hash acc (hash root_data))
          (scan_state root_data))
       (pending_coinbase root_data))
    (protocol_states root_data)

let merge_diff : type mutant. t -> (Diff.lite, mutant) Diff.t -> t =
 fun acc diff ->
  match diff with
  | New_node (Lite node) ->
      merge_transition acc node
  | Root_transitioned {new_root; garbage= Lite garbage_hashes} ->
      List.fold_left garbage_hashes
        ~init:(merge_root_data acc new_root)
        ~f:merge_state_hash
  | Best_tip_changed best_tip ->
      merge_state_hash acc best_tip
  (* Despite the fact that OCaml won't allow you to pass in a (full, mutant) Diff.t to this function,
     * the exhaustiveness checker is not convinced. This case cannot be reached. *)
  | _ ->
      failwith "impossible"

let merge_mutant : type mutant. t -> mutant Diff.Lite.t -> mutant -> t =
 fun acc diff mutant ->
  match diff with
  | New_node _ ->
      acc
  | Root_transitioned _ ->
      merge_state_hash acc mutant
  | Best_tip_changed _ ->
      merge_state_hash acc mutant

let merge_diff : type mutant. t -> mutant Diff.Lite.t -> mutant -> t =
 fun acc diff mutant -> merge_mutant (merge_diff acc diff) diff mutant
