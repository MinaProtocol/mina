(* unsigned_extended.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel
include Intf

[%%ifdef
consensus_mechanism]

open Snark_params
open Tick

[%%else]

open Snark_params_nonconsensus

[%%endif]

module type Unsigned_intf = Unsigned.S

module Extend
    (Unsigned : Unsigned.S) (M : sig
        val length : int
    end) : S with type t = Unsigned.t = struct
  ;;
  assert (M.length < Field.size_in_bits - 3)

  let length_in_bits = M.length

  module T = struct
    include Sexpable.Of_stringable (Unsigned)

    type t = Unsigned.t

    let compare = Unsigned.compare

    let equal t1 t2 = compare t1 t2 = 0

    let hash_fold_t s t = Int64.hash_fold_t s (Unsigned.to_int64 t)

    let hash t = Int64.hash (Unsigned.to_int64 t)
  end

  include T
  include Hashable.Make (T)

  include (Unsigned : Unsigned_intf with type t := t)

  (* serializes to and from json as strings since bit lengths > 32 cannot be represented in json *)
  let to_yojson n = `String (to_string n)

  let of_yojson = function
    | `String s ->
        Ok (of_string s)
    | _ ->
        Error "expected string"

  let ( < ) x y = compare x y < 0

  let ( > ) x y = compare x y > 0

  let ( = ) x y = compare x y = 0

  let ( <= ) x y = compare x y <= 0

  let ( >= ) x y = compare x y >= 0
end

module UInt64 = struct
  module M =
    Extend
      (Unsigned.UInt64)
      (struct
        let length = 64
      end)

  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Unsigned.UInt64.t

      let to_latest = Fn.id

      (* these are defined in the Extend functor, rather than derived, so import them *)
      [%%define_locally
      M.
        ( equal
        , compare
        , hash
        , hash_fold_t
        , sexp_of_t
        , t_of_sexp
        , to_yojson
        , of_yojson )]

      include Bin_prot.Utils.Make_binable (struct
        module Binable = Int64

        type t = Unsigned.UInt64.t

        let to_binable = Unsigned.UInt64.to_int64

        let of_binable = Unsigned.UInt64.of_int64
      end)
    end
  end]

  include M

  let to_uint64 : t -> uint64 = Fn.id

  let of_uint64 : uint64 -> t = Fn.id
end

module UInt32 = struct
  module M =
    Extend
      (Unsigned.UInt32)
      (struct
        let length = 32
      end)

  module Stable = struct
    module V1 = struct
      type t = Unsigned.UInt32.t [@@deriving version {binable}]

      (* these are defined in the Extend functor, rather than derived, so import them *)
      [%%define_locally
      M.
        ( equal
        , compare
        , hash
        , hash_fold_t
        , sexp_of_t
        , t_of_sexp
        , to_yojson
        , of_yojson )]

      include Bin_prot.Utils.Make_binable (struct
        module Binable = Int32

        type t = Unsigned.UInt32.t

        let to_binable = Unsigned.UInt32.to_int32

        let of_binable = Unsigned.UInt32.of_int32
      end)
    end

    module Latest = V1
  end

  include M

  let to_uint32 : t -> uint32 = Fn.id

  let of_uint32 : uint32 -> t = Fn.id
end

(* check that serializations don't change *)
let%test_module "Unsigned serializations" =
  ( module struct
    open Module_version.Serialization

    let%test "UInt32 V1 serialization" =
      let uint32 = UInt32.of_int 9775 in
      let known_good_hash =
        "\xDD\x22\xFB\x81\x59\xD2\x98\x81\x60\x82\x7D\x26\x48\xB8\x2D\x61\xB0\x65\xB5\xDC\x02\x54\x02\x03\x16\x66\xD4\xDE\xD1\xA2\xD8\x66"
      in
      check_serialization (module UInt32.Stable.V1) uint32 known_good_hash

    let%test "UInt64 V1 serialization" =
      let uint64 = UInt64.of_int64 191797697848L in
      let known_good_hash =
        "\x26\xA8\x3E\xB9\xCA\x2A\xDE\x52\xD3\xB7\x95\x36\x61\xAD\xCB\xA8\x1C\x71\x50\xE9\xAC\x07\xE8\xD9\x50\x5B\x8F\x36\x8D\x6E\xAE\x27"
      in
      check_serialization (module UInt64.Stable.V1) uint64 known_good_hash
  end )
