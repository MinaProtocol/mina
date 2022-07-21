(* verification_key_wire.ml *)

open Core_kernel
open Zkapp_basic

(* the digest functions are declared locally in Zkapp_account, which depends on
   this module; the definitions here avoid a cyclic dependency
*)

let digest_vk (t : Side_loaded_verification_key.t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.side_loaded_vk
      (pack_input (Side_loaded_verification_key.to_input t)))

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

      let to_binable (t : t) = t.data

      let of_binable vk : t =
        let data = vk in
        let hash = digest_vk vk in
        { data; hash }
    end

    include
      Binable.Of_binable_without_uuid
        (Side_loaded_verification_key.Stable.V2)
        (M)
  end
end]

let deriver obj : _ Fields_derivers_zkapps.Unified_input.t =
  let open Fields_derivers_zkapps in
  let module Vk = Side_loaded_verification_key in
  iso_string obj ~name:"VerificationKey" ~js_type:String
    ~doc:"Verification key in Base58Check format"
    ~to_string:(Fn.compose Vk.to_base58_check With_hash.data)
    ~of_string:
      (except
         ~f:
           (Fn.compose
              (With_hash.of_data ~hash_data:digest_vk)
              Vk.of_base58_check_exn )
         `Verification_key )

let%test_unit "json roundtrip" =
  let open Fields_derivers_zkapps in
  let open Side_loaded_verification_key in
  let v = With_hash.of_data ~hash_data:digest_vk dummy in
  let o = deriver @@ o () in
  [%test_eq: (t, F.t) With_hash.t] v (of_json o (to_json o v))
