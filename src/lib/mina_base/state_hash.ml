(* state_hash.ml *)
open Core_kernel
module T = Data_hash_lib.State_hash
include T

module State_hashes = struct
  type t =
    { mutable state_body_hash : State_body_hash.t option; state_hash : T.t }
  [@@deriving equal, sexp, to_yojson]

  let state_hash { state_hash; _ } = state_hash

  let state_body_hash t ~compute_hashes =
    match t.state_body_hash with
    | Some state_body_hash ->
        state_body_hash
    | None ->
        let { state_hash; state_body_hash } = compute_hashes () in
        assert (T.equal state_hash t.state_hash) ;
        assert (Option.is_some state_body_hash) ;
        t.state_body_hash <- state_body_hash ;
        Option.value_exn state_body_hash
end

module With_state_hashes = struct
  type 'a t = ('a, State_hashes.t) With_hash.t
  [@@deriving equal, sexp, to_yojson]

  open With_hash
  open State_hashes

  let data { data; _ } = data

  let hashes { hash = hashes; _ } = hashes

  let state_hash { hash = { state_hash; _ }; _ } = state_hash

  let state_body_hash { hash; data } ~compute_hashes =
    State_hashes.state_body_hash hash ~compute_hashes:(fun () ->
        compute_hashes data )
end
