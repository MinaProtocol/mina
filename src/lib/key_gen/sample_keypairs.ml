open Core_kernel
open Signature_lib

let kps =
  lazy
    (let n = 1200 in
     let generated_keypairs =
       let sks =
         Quickcheck.(
           random_value ~seed:(`Deterministic "Coda_sample_keypairs")
             (Generator.list_with_length n Private_key.gen))
       in
       List.map sks ~f:Keypair.of_private_key_exn
     in
     List.cons
       (* FIXME #2936: remove this "precomputed VRF keypair" *)
       (* This key is also at the start of all the release ledgers. It's needed to generate a valid genesis transition *)
       (Keypair.of_private_key_exn
          (Private_key.of_base58_check_exn
             "EKFKgDtU3rcuFTVSEpmpXSkukjmX4cKefYREi6Sdsk7E7wsT7KRw" ) )
       generated_keypairs )

let keypairs =
  Lazy.map kps ~f:(fun a ->
      Array.of_list_map a ~f:(fun kp ->
          (Public_key.compress kp.public_key, kp.private_key) ) )

let main () =
  let json =
    `List
      (List.map (Lazy.force kps) ~f:(fun kp ->
           `Assoc
             [ ( "public_key"
               , `String
                   Public_key.(
                     Compressed.to_base58_check (compress kp.public_key)) )
             ; ( "private_key"
               , `String (Private_key.to_base58_check kp.private_key) )
             ] ) )
  in
  Out_channel.with_file "sample_keypairs.json" ~f:(fun json_file ->
      Yojson.pretty_to_channel json_file json ) ;
  exit 0
