(* verification_key_wire.ml *)

open Core
open Zkapp_basic

(* the digest functions are declared locally in Zkapp_account, which depends on
   this module; the definitions here avoid a cyclic dependency
*)

let digest_vk (t : Side_loaded_verification_key.t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.side_loaded_vk
      (pack_input (Side_loaded_verification_key.to_input t)) )

let dummy_vk_hash =
  Memo.unit (fun () -> digest_vk Side_loaded_verification_key.dummy)

[%%versioned_binable
module Stable = struct
  module V1 = struct
    module T = struct
      type t = (Side_loaded_verification_key.t, F.t) With_hash.t
      [@@deriving sexp, yojson, equal, compare, hash]
    end

    include T

    let to_latest = Fn.id

    module M = struct
      type nonrec t = t

      (* don't send hash over the wire; restore hash on receipt *)

      (* The in-memory key is the widened [Side_loaded_verification_key.t], but
         the ledger keeps the [V2] encoding, which only admits keys verifying
         at most 2 proofs. This is why [Stable.V1] keeps its version number:
         the bytes are unchanged, and [to_stable_v2] raises for a wider key. *)

      let to_binable (t : t) = Side_loaded_verification_key.to_stable_v2 t.data

      let of_binable vk : t =
        let data = Side_loaded_verification_key.of_stable_v2 vk in
        let hash = digest_vk data in
        { data; hash }
    end

    include
      Binable.Of_binable_without_uuid
        (Side_loaded_verification_key.Stable.V2)
        (M)
  end
end]
