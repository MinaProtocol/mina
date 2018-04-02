open Core
open Async
open Nanobit_base
open Snark_params

module Transition = Nanobit_base.Blockchain_transition
;;

let real_tick_vk, tick_vk, tick_pk =
  if Insecure.key_generation then
    let kp =
      let open Tick in
      generate_keypair Data_spec.[Boolean.typ] (fun b -> Boolean.Assert.is_true b)
    in
    `Insecure,
    Tick.Verification_key.to_bigstring (Tick.Keypair.vk kp),
    Tick.Proving_key.to_bigstring (Tick.Keypair.pk kp)
  else
    let open Transition in
    let tick_kp =
      Tick.generate_keypair (Step_base.input ()) Step_base.main
    in
    let raw_tick_vk = Tick.Keypair.vk tick_kp in
      `Secure raw_tick_vk,
      Tick.Verification_key.to_bigstring raw_tick_vk,
      Tick.Proving_key.to_bigstring (Tick.Keypair.pk tick_kp)

let tock_vk, tock_pk =
  match real_tick_vk with
  | `Insecure ->
    let kp =
      let open Tock in
      generate_keypair Data_spec.[Boolean.typ] (fun b -> Boolean.Assert.is_true b)
    in
    Tock.Verification_key.to_bigstring (Tock.Keypair.vk kp),
    Tock.Proving_key.to_bigstring (Tock.Keypair.pk kp)
  | `Secure tick_vk ->
    let open Transition in
    let module Wrap_base_applied = Transition.Wrap_base(struct
      let verification_key = tick_vk
    end) in
    let tock_kp =
      Tock.generate_keypair (Wrap_base_applied.input ()) Wrap_base_applied.main
    in
      Tock.Verification_key.to_bigstring (Tock.Keypair.vk tock_kp),
      Tock.Proving_key.to_bigstring (Tock.Keypair.pk tock_kp)

let transaction_snark_keys =
  let keys =
    if Insecure.key_generation
    then Transaction_snark.Keys.dummy ()
    else Transaction_snark.Keys.create ()
  in
  let size = Transaction_snark.Keys.bin_size_t keys in
  let buf = Bigstring.create size in
  assert (Transaction_snark.Keys.bin_write_t buf ~pos:0 keys = size);
  buf

let _ =
  let do_write name key =
    let%bind writer = Writer.open_file (Printf.sprintf "/tmp/nanobit_%s" name) in
    Writer.write_bigstring writer key;
    Writer.close writer
  in
  let tick_pk_size, tick_vk_size, tock_pk_size, tock_vk_size =
    let l = Bigstring.length in
    (l tick_pk, l tick_vk, l tock_pk, l tock_vk)
  in
  let%map () = do_write "tick_pk" tick_pk
      and () = do_write "tick_vk" tick_vk
      and () = do_write "tock_pk" tock_pk
      and () = do_write "tock_vk" tock_vk
      and () = do_write "transaction_snark_keys" transaction_snark_keys
  in
  (* TODO Sha *)
  let open Md5 in
  let tick_pk_digest, tick_vk_digest, tock_pk_digest, tock_vk_digest, transaction_snark_keys_digest =
    let d b = digest_bytes (Bigstring.to_bytes b) in
    (d tick_pk, d tick_vk, d tock_pk, d tock_vk, d transaction_snark_keys)
  in
  let code = Printf.sprintf
    "
    module Make (Unit : sig end) = struct
      open Core
      open Nanobit_base
      open Blockchain_transition
      open Snark_params

      module Transition = Blockchain_transition

      let tick_vk_bs, tick_pk_bs, tock_vk_bs, tock_pk_bs =
        let do_read name length =
          let ic = In_channel.create (\"/tmp/nanobit_\" ^ name) in
          let buf = Buffer.create length in
          match In_channel.input_buffer ic buf ~len:length with
          | Some () ->
            Bigstring.of_bytes (Buffer.to_bytes buf)
          | None -> failwith \"Failed to fill buf\"
        in
        let tick_vk = do_read \"tick_vk\" %d
          and tick_pk = do_read \"tick_pk\" %d
          and tock_vk = do_read \"tock_vk\" %d
          and tock_pk = do_read \"tock_pk\" %d
        in
        let d b = Md5.digest_bytes (Bigstring.to_bytes b) in
        assert Md5.((d tick_vk) = (of_hex_exn \"%s\"));
        assert Md5.((d tick_pk) = (of_hex_exn \"%s\"));
        assert Md5.((d tock_vk) = (of_hex_exn \"%s\"));
        assert Md5.((d tock_pk) = (of_hex_exn \"%s\"));
        (tick_vk, tick_pk, tock_vk, tock_pk)

      let tick_vk = Tick.Verification_key.of_bigstring tick_vk_bs

      module Step = Transition.Step(struct
        let verification_key = tick_vk
        let proving_key = Tick.Proving_key.of_bigstring tick_pk_bs
      end) 

      module Wrap = Transition.Wrap
          (struct (* Step_vk *)
            let verification_key = tick_vk
          end) (struct (* Tock_keypair *)
            let verification_key = Tock.Verification_key.of_bigstring tock_vk_bs
            let proving_key = Tock.Proving_key.of_bigstring tock_pk_bs
          end)

      let transaction_snark_keys =
        let b = Bigstring.of_string (In_channel.read_all \"/tmp/nanobit_transaction_snark_keys\") in
        assert Md5.(Md5.digest_bytes (Bigstring.to_bytes b) = of_hex_exn \"%s\");
        Transaction_snark.Keys.bin_read_t b ~pos_ref:(ref 0)
    end
    " tick_vk_size tick_pk_size tock_vk_size tock_pk_size
    (to_hex tick_vk_digest)
    (to_hex tick_pk_digest)
    (to_hex tock_vk_digest)
    (to_hex tock_pk_digest)
    (to_hex transaction_snark_keys_digest)
  in

  let%map _ = Process.run_exn ~prog:"/bin/bash" ~args:[ "-c"; Printf.sprintf "echo \'%s\' > %s" code Sys.argv.(1)  ] () in
  exit 0
;;

let () = never_returns (Scheduler.go ())

