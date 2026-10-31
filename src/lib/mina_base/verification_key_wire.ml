(* verification_key_wire.ml *)

open Core_kernel
open Zkapp_basic

(* the digest functions are declared locally in Zkapp_account, which depends on
   this module; the definitions here avoid a cyclic dependency
*)

let digest_vk (t : Side_loaded_verification_key.t) =
  Random_oracle.(
    hash ~init:Hash_prefix_states.side_loaded_vk
      (pack_input (Side_loaded_verification_key.to_input t)))

let dummy_vk_hash =
  Memo.unit (fun () -> digest_vk Side_loaded_verification_key.dummy)

(** A verification key's hash, computed when it is first forced. *)
module Lazy_hash = struct
  type t = F.t Lazy.t

  let sexp_of_t t = F.sexp_of_t (Lazy.force t)

  let t_of_sexp sexp = Lazy.from_val (F.t_of_sexp sexp)

  let to_yojson t = F.to_yojson (Lazy.force t)

  let of_yojson json = Result.map (F.of_yojson json) ~f:Lazy.from_val

  let equal t1 t2 = F.equal (Lazy.force t1) (Lazy.force t2)

  let compare t1 t2 = F.compare (Lazy.force t1) (Lazy.force t2)

  let hash_fold_t state t = F.hash_fold_t state (Lazy.force t)
end

[%%versioned_binable
module Stable = struct
  module V1 = struct
    module T = struct
      type t = (Side_loaded_verification_key.t, Lazy_hash.t) With_hash.t
      [@@deriving sexp, yojson, equal, compare, hash]
    end

    include T

    let to_latest = Fn.id

    module M = struct
      type nonrec t = t

      (* don't send hash over the wire; compute it on receipt when first used *)

      let to_binable (t : t) = t.data

      let of_binable data : t = { data; hash = lazy (digest_vk data) }
    end

    include
      Binable.Of_binable_without_uuid
        (Side_loaded_verification_key.Stable.V2)
        (M)
  end
end]

(** The key's hash, computing it the first time it is asked for.

    The hash is memoised with [Lazy], so a key must not be shared with another
    thread that might ask for its hash at the same time.
*)
let hash (t : t) = Lazy.force t.hash

(** A key whose hash is that of [data], computed when first used. *)
let of_data data : t = { data; hash = lazy (digest_vk data) }

let to_hashed ({ data; hash } : t) :
    (Side_loaded_verification_key.t, F.t) With_hash.t =
  { data; hash = Lazy.force hash }

let of_hashed
    ({ data; hash } : (Side_loaded_verification_key.t, F.t) With_hash.t) : t =
  { data; hash = Lazy.from_val hash }
