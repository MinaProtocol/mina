open Signature_lib

(* This file should be replaced with the production version when building
   for production *)

let t =
  Private_key.of_base64_exn
    "KI7nBg2r3Hl1j/jFv5RoePloNjioAL96ac4UHBhR8i1kopq+w0IBAAA="

let mode : [`Dev | `Prod] = `Prod
