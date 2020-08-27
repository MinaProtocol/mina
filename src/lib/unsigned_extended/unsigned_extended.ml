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

    let hash_fold_t s t = Int64.hash_fold_t s (Unsigned.to_int64 t)

    let hash t = Int64.hash (Unsigned.to_int64 t)

    let to_bigint t =
      let i64 = Unsigned.to_int64 t in
      if Int64.(i64 >= 0L) then Bignum_bigint.of_int64 i64
      else
        Bignum_bigint.(
          of_int64 i64 - of_int64 Int64.min_value + of_int64 Int64.max_value
          + one)
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
    [@@@no_toplevel_latest_type]

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

  [%%versioned_binable
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = Unsigned.UInt32.t

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
        module Binable = Int32

        type t = Unsigned.UInt32.t

        let to_binable = Unsigned.UInt32.to_int32

        let of_binable = Unsigned.UInt32.of_int32
      end)
    end
  end]

  include M

  let to_uint32 : t -> uint32 = Fn.id

  let of_uint32 : uint32 -> t = Fn.id
end

(* check that serializations don't change *)
let%test_module "Unsigned serializations" =
  ( module struct
    open Ppx_version_runtime.Serialization

    let%test "UInt32 V1 serialization" =
      let uint32 = UInt32.of_int 9775 in
      let known_good_digest = "b66e8ba9d68f2d08bafaa3abd3abccba" in
      check_serialization (module UInt32.Stable.V1) uint32 known_good_digest

    let%test "UInt64 V1 serialization" =
      let uint64 = UInt64.of_int64 191797697848L in
      let known_good_digest = "9a34874c0a6a0c797b19d1f756f39103" in
      check_serialization (module UInt64.Stable.V1) uint64 known_good_digest
  end )
