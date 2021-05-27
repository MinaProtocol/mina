(* generate_keypair.ml -- utility app that only generates keypairs *)

open Core_kernel
open Async

module type Test_intf = sig
  type t [@@deriving bin_io]

  val v : t
end

module Tests = struct
  module A : Test_intf = struct
    type t = Nat0.t [@@deriving bin_io]

    let v = Nat0.one
  end
end

module Flags = struct
  let test =
    let open Command.Param in
    flag "--test" ~aliases:["test"] ~doc:"NAME Name of the test to run"
      (Command.Param.map (fun _ -> (module Tests.A)) string)
end

let serialize =
  Command.async ~summary:"Serialize bin_prot data to a file"
    (let open Command.Let_syntax in
     let%map_open test_case = Flags.test in
     Exceptions.handle_nicely
     @@ fun () ->
     let open Deferred.Let_syntax in
     let (module A) = (val a : Test_intf) in

     A.bin_write_t A.v
     exit 0)

let deserialize_and_check =
  Command.async
    ~summary:"Deserialize bin_prot data from a file and verify it is valid"
    (let open Command.Let_syntax in
     let%map_open privkey_path = Flag.privkey_write_path in
     Exceptions.handle_nicely
     @@ fun () ->
     let open Deferred.Let_syntax in
     let kp = Keypair.create () in
     let%bind () = Secrets.Keypair.Terminal_stdin.write_exn kp ~privkey_path in
     printf "Keypair generated\nPublic key: %s\nRaw public key: %s\n"
       ( kp.public_key |> Public_key.compress
         |> Public_key.Compressed.to_base58_check )
       (Rosetta_coding.Coding.of_public_key kp.public_key) ;
     exit 0)

let () = Command.run Cli_lib.Commands.generate_keypair
