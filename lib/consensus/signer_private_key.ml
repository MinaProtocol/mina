open Signature_lib

let signer_private_key =
  Private_key.of_base64_exn
    "KILGqiEH+yaadqf3dljOiEhAfJ21rmo7R08/ZKa3Ehp68RinDEECAAA="

let mode : [`Dev | `Prod] = `Dev
