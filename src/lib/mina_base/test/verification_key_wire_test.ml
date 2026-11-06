open Core_kernel
open Mina_base

(* The dummy key has no wrap key, so build it by decoding the dummy. *)
let data =
  Pickles.Side_loaded.Verification_key.(
    dummy |> to_base58_check |> of_base58_check_exn)

let decode (vk : Verification_key_wire.t) =
  let module M = Verification_key_wire.Stable.Latest in
  Binable.of_string (module M) (Binable.to_string (module M) vk)

let hash_is_computed_when_first_used () =
  let vk =
    decode (Verification_key_wire.of_hashed { data; hash = Zkapp_basic.F.one })
  in
  Alcotest.(check bool)
    "decoding does not compute the hash" false (Lazy.is_val vk.hash) ;
  Alcotest.(check bool)
    "the hash is recomputed from the key, not sent with it" true
    (Zkapp_basic.F.equal
       (Verification_key_wire.hash vk)
       (Verification_key_wire.digest_vk data) )

let known_hash_is_kept () =
  let vk = Verification_key_wire.of_hashed { data; hash = Zkapp_basic.F.one } in
  Alcotest.(check bool)
    "the given hash is kept" true
    (Zkapp_basic.F.equal (Verification_key_wire.hash vk) Zkapp_basic.F.one)

let tests =
  ( "verification key wire"
  , [ Alcotest.test_case "A decoded key's hash is computed when first used"
        `Quick hash_is_computed_when_first_used
    ; Alcotest.test_case "A key built with its hash keeps that hash" `Quick
        known_hash_is_kept
    ] )
