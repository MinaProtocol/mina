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

  module Stable = struct
    module V1 = struct
      type t = Unsigned.UInt64.t [@@deriving version {of_binable}]

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

    module Latest = V1
  end

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
      type t = Unsigned.UInt32.t [@@deriving version {of_binable}]

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
    let run_test (type t) (module M : Bin_prot.Binable.S with type t = t)
        known_good_serialization (value : t) =
      let buff = Bin_prot.Common.create_buf 256 in
      let len = M.bin_write_t buff ~pos:0 value in
      let bytes = Bytes.create len in
      Bin_prot.Common.blit_buf_bytes buff bytes ~len ;
      Bytes.equal bytes known_good_serialization

    let%test "UInt32 V1 serialization" =
      let uint32 = UInt32.of_int 9775 in
      let known_good_serialization = Bytes.of_string "\xFE\x2F\x26" in
      run_test (module UInt32.Stable.V1) known_good_serialization uint32

    let%test "UInt64 V1 serialization" =
      let uint64 = UInt64.of_int64 191797697848L in
      let known_good_serialization =
        Bytes.of_string "\xFC\x38\x9D\x08\xA8\x2C\x00\x00\x00"
      in
      run_test (module UInt64.Stable.V1) known_good_serialization uint64
  end )
