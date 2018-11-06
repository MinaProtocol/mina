open Core_kernel
open Lite_base
module Proof_system = Lite_base.Crypto_params.Tock.Groth_maller

module Make_stringable_of_base64_binable (T : Binable.S) = struct
  let to_string = Fn.compose B64.encode (Binable.to_string (module T))

  let of_string = Fn.compose (Binable.of_string (module T)) B64.decode
end

module Query = struct
  module T = struct
    type t = Lite_chain.t * int [@@deriving bin_io]
  end

  include T
  include Make_stringable_of_base64_binable (T)
end

module Response = struct
  module T = struct
    type result = {state_hash: Pedersen.Digest.t} [@@deriving bin_io]

    type t = Query.t * result Or_error.t [@@deriving bin_io]
  end

  include T
  include Make_stringable_of_base64_binable (T)

  let id (((_, id), _) : t) = id

  let result ((_, r) : t) = r
end

type t = (Js.js_string Js.t, Js.js_string Js.t) Worker.worker Js.t

let verifier_main = "/static/verifier_main.bc.js"

let create () = Worker.create verifier_main

let send_verify_message (t : t) q =
  t##postMessage (Js.string (Query.to_string q))

let set_on_message (t : t) ~f =
  t##.onmessage :=
    Dom.handler (fun q ->
        f (Response.of_string (Js.to_string q##.data)) ;
        Js._false )
