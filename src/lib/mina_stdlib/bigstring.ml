open Core

(* add functions to library module Bigstring so we can derive hash for the type t below *)

[%%versioned_binable
module Stable = struct
  module V1 = struct
    type t = Bigstring.Stable.V1.t [@@deriving sexp, compare]

    let to_latest = Fn.id

    let hash t = Bigstring.to_string t |> String.hash

    let hash_fold_t hash_state t =
      String.hash_fold_t hash_state (Bigstring.to_string t)

    include Bounded_types.String.Of_stringable (struct
      type nonrec t = t

      let of_string s = Bigstring.of_string s

      let to_string s = Bigstring.to_string s
    end)
  end
end]

include Hashable.Make (Stable.Latest)
open Bigstring

[%%define_from_scope get, length, create, to_string, set, blit, sub]
