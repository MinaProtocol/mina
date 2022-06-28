open Core_kernel

(* unused type *)
[@@@warning "-34"]

(* Basic test. *)
module M1 = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type t = int [@@deriving equal]

      let to_latest = Fn.id
    end

    module V2 = struct
      type t = int

      let to_latest = Fn.id
    end

    module V1 = struct
      type t = bool

      let to_latest b = if b then 1 else 0
    end
  end]
end

let () =
  let x = 15 in
  let buf = Bigstring.create 10 in
  (* Test writing given version. *)
  ignore (M1.Stable.V3.bin_write_t buf ~pos:0 x : int) ;
  (* Test that reads are compatible with [With_version]. *)
  let y : M1.Stable.V3.With_version.t =
    M1.Stable.V3.With_version.bin_read_t buf ~pos_ref:(ref 0)
  in
  assert (y.version = 3) ;
  assert (y.t = x) ;
  (* Test that what was read is what was written. *)
  let z = M1.Stable.V3.bin_read_t buf ~pos_ref:(ref 0) in
  assert (z = x) ;
  (* Test that trying to read the wrong version results in an assertion
     failure.
  *)
  ( try
      ignore (M1.Stable.V2.bin_read_t buf ~pos_ref:(ref 0) : int) ;
      assert false
    with Failure _ -> () ) ;
  (* Test that [bin_read_to_latest_opt] finds and uses the right
     deserialisation.
  *)
  match M1.Stable.bin_read_to_latest_opt buf ~pos_ref:(ref 0) with
  | Some a ->
      assert (a = x)
  | None ->
      assert false

(* No [to_latest] necessary because the latest version takes a parameter. *)
module M2 = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type 'a t = { a : 'a; b : int } [@@deriving equal]
    end

    module V2 = struct
      type 'a t = { b : M1.Stable.V3.t; a : 'a }
    end

    module V1 = struct
      type t = { a : M1.Stable.V1.t }
    end
  end]
end

(* No [to_latest] necessary when older versions have parameters. *)
module M3 = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      type t = { a : bool; b : int }

      let to_latest = Fn.id
    end

    module V2 = struct
      type 'a t = { b : M1.Stable.V3.t; a : 'a }
    end

    module V1 = struct
      type t = { a : M1.Stable.V1.t }

      let to_latest { a } = { V3.a; b = (if a then 1 else 0) }
    end
  end]
end

(* Test that types with arguments are still annotated with the correct
   versions.
*)
let () =
  (* Choose a value that could deserialise to [M2.Stable.V3.t] and [V2.t] if
     not for the versioning checks.
  *)
  let x : M1.Stable.V3.t M2.Stable.V3.t = { M2.a = 15; b = 15 } in
  let buf = Bigstring.create 20 in
  (* Test writing given version. *)
  ignore (M2.Stable.V3.bin_write_t M1.Stable.V3.bin_write_t buf ~pos:0 x : int) ;
  (* Test that reads are compatible with [With_version]. *)
  let y : M1.Stable.V3.t M2.Stable.V3.With_version.t =
    M2.Stable.V3.With_version.bin_read_t M1.Stable.V3.bin_read_t buf
      ~pos_ref:(ref 0)
  in
  assert (y.version = 3) ;
  assert (M2.Stable.V3.equal Int.equal y.t x) ;
  (* Test that what was read is what was written. *)
  let z =
    M2.Stable.V3.bin_read_t M1.Stable.V3.bin_read_t buf ~pos_ref:(ref 0)
  in
  assert (M2.Stable.V3.equal Int.equal z x) ;
  (* Test that trying to read the wrong version results in an assertion
     failure.
     Note: these types will serialise to the same thing, as
     [int M2.Stable.V3.t = {b: M1.Stable.V3.t; a: int}]
     [M1.Stable.V3.t M2.Stable.V3.t = {a: M1.Stable.V3.t; b: int}]
  *)
  try
    ignore
      ( M2.Stable.V3.bin_read_t bin_read_int buf ~pos_ref:(ref 0)
        : int M2.Stable.V3.t ) ;
    assert false
  with Assert_failure _ -> ()

(* Test that annotations on the types are accepted. *)
module M4 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = { a : bool; b : int } [@@deriving sexp, equal]

      let to_latest = Fn.id
    end
  end]
end

(* Allow binable functor *)
module M5 = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = bool

      let to_latest = Fn.id

      module Arg = struct
        type nonrec t = t

        let to_binable = Fn.id

        let of_binable = Fn.id
      end

      include Binable.Of_binable_without_uuid (Core_kernel.Bool.Stable.V1) (Arg)
    end
  end]
end

(* Test that a version annotation is accepted, and the standard version
   annotation isn't also added.
*)
module M6 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Bool.t [@@deriving version { asserted }]

      let to_latest = Fn.id
    end
  end]
end

module M7 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = M1.Stable.V3.t M2.Stable.V3.t [@@deriving equal]

      let to_latest = Fn.id
    end
  end]
end

(* Test that types applied to parameters are properly versioned. *)
let () =
  let x : M7.Stable.V1.t = { a = 15; b = 20 } in
  let buf = Bigstring.create 20 in
  (* Test writing given version. *)
  ignore (M7.Stable.V1.bin_write_t buf ~pos:0 x : int) ;
  (* Test that reads are compatible with [With_version]. *)
  let y : M7.Stable.V1.With_version.t =
    M7.Stable.V1.With_version.bin_read_t buf ~pos_ref:(ref 0)
  in
  assert (y.version = 1) ;
  assert (M7.Stable.V1.equal y.t x) ;
  (* Test that what was read is what was written. *)
  let z = M7.Stable.V1.bin_read_t buf ~pos_ref:(ref 0) in
  assert (M7.Stable.V1.equal z x)

(* Test that modules may have other contents besides the type declarations. *)
module M8 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int

      let some = 1

      let other = 2

      let things = 3

      let (_ : int * int * int) = (some, other, things)

      let to_latest = Fn.id

      module X = struct
        type t = bool
      end

      module type Y = sig
        type t
      end

      module F (X : Y) = struct
        type y = t

        include X
      end

      include (
        F
          (X) :
            sig
              type y = t
            end )
    end
  end]

  module X = struct
    open Stable.V1

    let (_ : int * int * int) = (some, other, things)

    module X = X

    module type Y = Y

    module F = F

    type y = Stable.V1.y
  end
end
