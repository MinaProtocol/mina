open Core
open Sodium

module Stable = struct
  module V1 = struct
    type t =
      { box_primitive: string
      ; pw_primitive: string
      ; nonce: Bytes.t
      ; pwsalt: Bytes.t
      ; pwdiff: Int64.t * int
      ; ciphertext: Bytes.t }
    [@@deriving sexp]
  end
end

include Stable.V1

(** warning: this will zero [password] *)
let encrypt ~(password: Bytes.t) ~(plaintext: Bytes.t) =
  let nonce = Secret_box.random_nonce () in
  let salt = Password_hash.random_salt () in
  let ({Password_hash.mem_limit; ops_limit} as diff) =
    Password_hash.moderate
  in
  let pw = Password_hash.Bytes.wipe_to_password password in
  let key = Secret_box.derive_key diff pw salt in
  let ciphertext = Secret_box.Bytes.secret_box key plaintext nonce in
  { box_primitive= Secret_box.primitive
  ; pw_primitive= Password_hash.primitive
  ; nonce= Secret_box.Bytes.of_nonce nonce
  ; pwsalt= Password_hash.Bytes.of_salt salt
  ; pwdiff= (mem_limit, ops_limit)
  ; ciphertext }

(** warning: this will zero [password] *)
let decrypt_exn ~(password: Bytes.t)
    { box_primitive
    ; pw_primitive
    ; nonce
    ; pwsalt
    ; pwdiff= mem_limit, ops_limit
    ; ciphertext } =
  assert (box_primitive = Secret_box.primitive) ;
  assert (pw_primitive = Password_hash.primitive) ;
  let nonce = Secret_box.Bytes.to_nonce nonce in
  let salt = Password_hash.Bytes.to_salt pwsalt in
  let diff = {Password_hash.mem_limit; ops_limit} in
  let pw = Password_hash.Bytes.wipe_to_password password in
  let key = Secret_box.derive_key diff pw salt in
  Secret_box.Bytes.secret_box_open key ciphertext nonce
