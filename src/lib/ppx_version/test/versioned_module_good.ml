open Core_kernel

(* unused type *)
[@@@warning "-34"]

(* Basic test. *)
module M1 = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      [@@@with_all_version_tags]

      type t = int [@@deriving equal]

      let to_latest = Fn.id
    end

    module V2 = struct
      [@@@with_all_version_tags]

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
  ignore (M1.Stable.V3.With_all_version_tags.bin_write_t buf ~pos:0 x : int) ;
  (* Test that reads are compatible with [With_version]. *)
  let y : M1.Stable.V3.With_all_version_tags.t_tagged =
    M1.Stable.V3.With_all_version_tags.bin_read_t_tagged buf ~pos_ref:(ref 0)
  in
  assert (y.version = 3) ;
  assert (y.t = x) ;
  (* Test that what was read is what was written. *)
  let z = M1.Stable.V3.With_all_version_tags.bin_read_t buf ~pos_ref:(ref 0) in
  assert (z = x) ;
  (* Test that trying to read the wrong version results in an assertion
     failure.
  *)
  ( try
      ignore
        ( M1.Stable.V2.With_all_version_tags.bin_read_t buf ~pos_ref:(ref 0)
          : int ) ;
      assert false
    with Failure _ -> () ) ;
  (* Test that [bin_read_all_tagged_to_latest] finds and uses the right
     deserialisation.
  *)
  match M1.Stable.bin_read_all_tagged_to_latest buf ~pos_ref:(ref 0) with
  | Ok a ->
      assert (a = x)
  | Error _ ->
      assert false

module M2 = struct
  [%%versioned
  module Stable = struct
    module V3 = struct
      (* No [to_latest] necessary because the latest version takes a parameter. *)
      type 'a t = { a : 'a; b : int } [@@deriving equal]
    end

    module V2 = struct
      (* ditto *)
      type 'a t = { b : M1.Stable.V3.t; a : 'a }
    end

    module V1 = struct
      type t = { a : M1.Stable.V1.t }

      let to_latest = Fn.id
    end
  end]
end

module M3 = struct
  [%%versioned
  module Stable = struct
    [@@@with_top_version_tag]

    module V3 = struct
      type t = { a : bool; b : int } [@@deriving equal]

      let to_latest = Fn.id
    end

    module V2 = struct
      (* No [to_latest] necessary, has parameter *)
      type 'a t = { b : M1.Stable.V3.t; a : 'a }
    end

    module V1 = struct
      type t = { a : M1.Stable.V1.t }

      let to_latest { a } = { V3.a; b = (if a then 1 else 0) }
    end
  end]
end

(* Test top version tag write/read *)
let () =
  let x : M3.Stable.V3.t = { a = false; b = 15 } in
  let buf = Bigstring.create 20 in
  ignore (M3.Stable.V3.With_top_version_tag.bin_write_t buf ~pos:0 x : int) ;
  let y = M3.Stable.V3.With_top_version_tag.bin_read_t buf ~pos_ref:(ref 0) in
  assert (M3.Stable.V3.equal x y) ;
  let z =
    match M3.Stable.bin_read_top_tagged_to_latest buf ~pos_ref:(ref 0) with
    | Ok n ->
        n
    | Error _ ->
        assert false
  in
  assert (M3.Stable.V3.equal x z)

(* Test all version tags write/read *)
module M4 = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      [@@@with_all_version_tags]

      type t = { a : int; b : string } [@@deriving equal]

      let to_latest = Fn.id
    end

    module V1 = struct
      [@@@with_all_version_tags]

      type t = { a : string; b : int }

      let to_latest ({ a; b } : t) : Latest.t = { a = b; b = a }
    end
  end]
end

let () =
  let x : M4.Stable.V2.t = { a = 42; b = "hello" } in
  let buf = Bigstring.create 20 in
  ignore (M4.Stable.V2.With_all_version_tags.bin_write_t buf ~pos:0 x : int) ;
  let y = M4.Stable.V2.With_all_version_tags.bin_read_t buf ~pos_ref:(ref 0) in
  assert (M4.Stable.V2.equal x y) ;
  let z =
    match M4.Stable.bin_read_all_tagged_to_latest buf ~pos_ref:(ref 0) with
    | Ok n ->
        n
    | Error _ ->
        assert false
  in
  assert (M4.Stable.V2.equal x z)

(* version_asserted annotation *)
module M5 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (Bool.t[@version_asserted])

      let to_latest = Fn.id
    end
  end]
end

[@@@alert "-legacy"]

(* Allow binable functor *)
module M6 = struct
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

(* Test that modules may have other contents besides the type declarations. *)
module M7 = struct
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
