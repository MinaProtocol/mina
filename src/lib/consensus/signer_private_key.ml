(* This file should be replaced with the production version when building
   for production *)

let signer_private_key = snd Coda_base.Sample_keypairs.keypairs.(0)

let mode : [`Dev | `Prod] = `Dev
