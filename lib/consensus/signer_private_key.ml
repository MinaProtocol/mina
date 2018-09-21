open Signature_lib

(* This file should be replaced with the production version when building
   for production *)

let signer_private_key =
  Private_key.of_base64_exn
    "KILGqiEH+yaadqf3dljOiEhAfJ21rmo7R08/ZKa3Ehp68RinDEECAAA="

let mode : [`Dev | `Prod] = `Dev
