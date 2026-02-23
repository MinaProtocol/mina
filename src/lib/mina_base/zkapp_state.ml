open Core_kernel
open Pickles_types
module Max_state_size = Nat.N32

module State_length_vec :
  Vector.VECTOR with type 'a t = ('a, Max_state_size.n) Vector.vec =
  Vector.Vector_32

module V = struct
  (* Think about versioning here! These vector types *will* change
     serialization if the numbers above change, and so will require a new
     version number. Thus, it's important that these are modules with new
     versioned types, and not just module aliases to the corresponding vector
     implementation.
  *)
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type 'a t = 'a State_length_vec.Stable.V1.t
      [@@deriving compare, yojson, sexp, hash, equal]
    end
  end]

  type 'a t = 'a State_length_vec.t
  [@@deriving compare, yojson, sexp, hash, equal]

  let map = Vector.map

  let of_list_exn list = Vector.of_list_and_length_exn list Max_state_size.n

  let to_list = Vector.to_list

  let init : f:(int -> 'a) -> 'a t = fun ~f -> Vector.init Max_state_size.n ~f
end

let max_size_int : int = Nat.to_int Max_state_size.n

let _type_equal :
    type a. (a V.t, a Vector.With_length(Max_state_size).t) Type_equal.t =
  Type_equal.T

let typ t = Vector.typ t Max_state_size.n

open Core_kernel

module Value = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = Zkapp_basic.F.Stable.V1.t V.Stable.V2.t
      [@@deriving sexp, equal, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  type t = Zkapp_basic.F.t V.t [@@deriving sexp, equal, yojson, hash, compare]

  let (_ : (t, Stable.Latest.t) Type_equal.t) = Type_equal.T

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%map fields =
      Quickcheck.Generator.list_with_length max_size_int
        Snark_params.Tick.Field.gen
    in
    V.of_list_exn fields
end

let to_input (t : _ V.t) ~f =
  Vector.(reduce_exn (map t ~f) ~f:Random_oracle_input.Chunked.append)

let deriver inner obj =
  let open Fields_derivers_zkapps.Derivers in
  iso ~map:V.of_list_exn ~contramap:V.to_list
    ((list ~static_length:max_size_int @@ inner @@ o ()) (o ()))
    obj

module Hardfork = struct
  module Max_state_size = Nat.N32

  module State_length_vec :
    Vector.VECTOR with type 'a t = ('a, Max_state_size.n) Vector.vec =
    Vector.Vector_32

  module V = struct
    type 'a t = 'a State_length_vec.Stable.V1.t
    [@@deriving sexp, equal, hash, compare, yojson, bin_io_unversioned]
  end

  module Value = struct
    type t = Zkapp_basic.F.Stable.V1.t V.t
    [@@deriving sexp, equal, hash, compare, yojson, bin_io_unversioned]
  end
end
