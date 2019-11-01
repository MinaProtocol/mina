module Js = Js_of_ocaml.Js

(* let key = Demo.Verification_key.Processed.t_of_sexp *)

(* let verification_key = Snark_keys.blockchain_verification () *)

(* let deserialize js_str = *)
(*   let str = Js.to_bytestring js_str in *)
(*   let strlen = String.length str in *)
(*   let buf = Core_kernel.Bin_prot.Common.create_buf strlen in *)
(*   Core_kernel.Bin_prot.Common.blit_string_buf str buf ~len:strlen; *)
(*   Demo.Verification_key.bin_read_t buf ~pos_ref:(ref 0) *)

(* let deserialize_buffer buf = *)
(*   Demo.Verification_key.bin_read_t buf ~pos_ref:(ref 0) *)

(* let deserialize_processed_buffer buf = *)
(*   Demo.Verification_key.Processed.bin_read_t buf ~pos_ref:(ref 0) *)

(* module Checked_data = struct *)
(*   type 'a t = {checksum: Core_kernel.Md5.t; data: 'a} [@@deriving bin_io] *)
(* end *)

(* Demo.Verification_key. *)
(* let key = [%sexp: Demo.Verification_key.Processed.t] "(14124124214124)" *)

(* let deserialize_processed_buffer buf = *)
(*   let thing = *)
(*     (Checked_data.bin_read_t Core_kernel.Bin_prot.Read.bin_read_string) buf *)
(*     ~pos_ref:(ref 0) in *)
(*   Core_kernel.Binable.of_string (module Demo.Verification_key.Processed) thing.data *)

(* let deserialize_sexp buf = *)
(*   let thing = *)
(*     (Checked_data.bin_read_t Core_kernel.Bin_prot.Read.bin_read_string) buf *)
(*     ~pos_ref:(ref 0) in *)
(*   Core_kernel.Binable.of_string (module Demo.Verification_key.Processed) thing.data *)

(* let _ = Reader.load_bin_prot *)
(*         ~max_len:(5 * 512 * 1024 * 1024 (1* 2.5 GB *1)) *)
(*         location *)
(*         (bin_reader_t String.bin_reader_t   ) *)

(* var key = snarkette.createVerificationKey(msg.key); *)
(* var proof = snarkette.constructProof(a, b, c, delta_prime, z); *)
(* return snarkette.verifyStateHash(key, msg.stateHashField, proof) *)

let create_verification_key key_string =
  let key = Js.to_string key_string in
  let sexp = Core_kernel.Sexp.of_string key in
  Demo.Verification_key.t_of_sexp sexp
  |> Demo.Verification_key.Processed.create

let decode_g1 a =
  let open Snarkette.Mnt6753 in
  let open Core_kernel in
  Js.to_string a |> Sexp.of_string |> [%of_sexp: Fq.t * Fq.t] |> G1.of_affine

let decode_g2 a =
  let open Snarkette.Mnt6753 in
  let open Core_kernel in
  Js.to_string a |> Sexp.of_string
  |> [%of_sexp: (Fq.t * Fq.t * Fq.t) * (Fq.t * Fq.t * Fq.t)] |> G2.of_affine

let construct_proof a b c delta_prime z =
  let a = decode_g1 a in
  let b = decode_g2 b in
  let c = decode_g1 c in
  let delta_prime = decode_g2 delta_prime in
  let z = decode_g1 z in
  {Demo.Proof.a; b; c; delta_prime; z}

let bigint_of_string s = Snarkette.Nat.of_string (Js.to_string s)

let bigint_to_string bi = Js.string (Snarkette.Nat.to_string bi)

let verify_state_hash verification_key state_hash proof =
  Demo.verify verification_key [bigint_of_string state_hash] proof

let () =
  let window = Js.Unsafe.global in
  let snarkette_obj =
    let open Js.Unsafe in
    obj
      [| ("constructProof", inject construct_proof)
       ; ("createVerificationKey", inject create_verification_key)
         (* ; ("deserialize", inject(deserialize_buffer)) *)
         (* ; ("deserializeProcessed", inject(deserialize_processed_buffer)) *)
       ; ("verifyStateHash", inject verify_state_hash)
       ; ("bigintOfString", inject bigint_of_string)
       ; ("bigintToString", inject bigint_to_string)
         (* ; ("hash", inject(call_hash)) *) |]
  in
  Js.Unsafe.set window "snarkette" snarkette_obj
