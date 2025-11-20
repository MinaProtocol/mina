(* state_hash.ml *)
open Core_kernel
module T = Data_hash_lib.State_hash
include T

module State_hashes = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { mutable state_body_hash : State_body_hash.Stable.V1.t option
        ; state_hash : T.Stable.V1.t
        }
      [@@deriving equal, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

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
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type 'a t = ('a, State_hashes.Stable.V1.t) With_hash.Stable.V1.t
      [@@deriving equal, sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type 'a t = ('a, State_hashes.t) With_hash.t
  [@@deriving equal, sexp, to_yojson]

  open With_hash
  open State_hashes.Stable.Latest

  let data { data; _ } = data

  let hashes { hash = hashes; _ } = hashes

  let state_hash { hash = { state_hash; _ }; _ } = state_hash

  let state_body_hash { hash; data } ~compute_hashes =
    State_hashes.state_body_hash hash ~compute_hashes:(fun () ->
        compute_hashes data )
end

module Tag = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = (Stable.V1.t, 'a) Multi_key_file_storage.Tag.Stable.V1.t

      let compare a b = Multi_key_file_storage.Tag.compare Stable.V1.compare a b

      let equal a b = Multi_key_file_storage.Tag.equal Stable.V1.equal a b

      let sexp_of_t a =
        Multi_key_file_storage.Tag.sexp_of_t Stable.V1.sexp_of_t a

      let t_of_sexp sexp =
        Multi_key_file_storage.Tag.t_of_sexp Stable.V1.t_of_sexp sexp

      let to_latest = Fn.id
    end
  end]

  [%%define_locally Stable.Latest.(compare, equal, sexp_of_t, t_of_sexp)]
end

module File_storage = Multi_key_file_storage.Make_custom (struct
  type filename_key = t

  (* TODO replace with hex string, pass directory parameter *)
  let filename h = T.to_decimal_string h ^ ".dat"
end)
