open Core_kernel
open Signature_lib

(* FIXME #2936: remove this "precomputed VRF keypair" *)
(* This key is also at the start of all the release ledgers. It's needed to generate a valid genesis transition *)
let genesis_winner =
  let kp =
    Keypair.of_private_key_exn
      (Private_key.of_base58_check_exn
         "EKFKgDtU3rcuFTVSEpmpXSkukjmX4cKefYREi6Sdsk7E7wsT7KRw" )
  in
  (Public_key.compress kp.public_key, kp.private_key)

let generated_keypairs =
  lazy
    (let n = 1200 in
     let sks =
       Quickcheck.(
         random_value ~seed:(`Deterministic "Coda_sample_keypairs")
           (Generator.list_with_length n Private_key.gen))
     in
     List.map sks ~f:(function sk ->
         let kp = Keypair.of_private_key_exn sk in
         (Public_key.compress kp.public_key, kp.private_key) ) )

let keypairs =
  Lazy.map generated_keypairs ~f:(fun a ->
      Array.of_list (List.cons genesis_winner a) )

let main () =
  let json =
    `List
      (List.map
         (Array.to_list @@ Lazy.force keypairs)
         ~f:(fun (pk, sk) ->
           `Assoc
             [ ("public_key", `String Public_key.(Compressed.to_base58_check pk))
             ; ("private_key", `String (Private_key.to_base58_check sk))
             ] ) )
  in
  Out_channel.with_file "sample_keypairs.json" ~f:(fun json_file ->
      Yojson.pretty_to_channel json_file json ) ;
  exit 0
