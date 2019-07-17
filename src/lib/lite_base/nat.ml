module Make (Type : sig
  type t [@@deriving bin_io, eq, sexp, to_yojson, compare, version]
end)
(Impl : sig
          type t

          include Base.Stringable.S with type t := t

          val length_in_bits : int

          val one : t

          val logand : t -> t -> t

          val shift_right_logical : t -> int -> t
        end
        with type t := Type.t) =
struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Type.t
        [@@deriving bin_io, eq, sexp, to_yojson, compare, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving eq, sexp, to_yojson, compare]

  let length_in_triples = (Impl.length_in_bits + 2) / 3

  let fold t : bool Fold_lib.Fold.t =
    { fold=
        (fun ~init ~f ->
          let rec go acc pt i =
            if i = Impl.length_in_bits then acc
            else
              let b = Impl.(equal (logand one pt) one) in
              go (f acc b) (Impl.shift_right_logical pt 1) (i + 1)
          in
          go init t 0 ) }

  let fold t = Fold_lib.Fold.group3 ~default:false (fold t)

  module Impl = struct
    type t = Stable.Latest.t [@@deriving eq, sexp, compare]

    let length_in_triples, fold = (length_in_triples, fold)
  end
end

module Input_32 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        open Core_kernel

        type t = int32
        [@@deriving bin_io, eq, sexp, to_yojson, compare, version]
      end

      include T
    end
  end

  module Impl = struct
    let to_string = Int32.to_string

    let of_string = Int32.of_string

    let logand = Int32.logand

    let one = Int32.one

    let zero = Int32.zero

    let shift_right_logical = Int32.shift_right_logical

    let length_in_bits = 32
  end
end

module Make32 () = struct
  module Stable = struct
    module V1 = Make (Input_32.Stable.V1) (Input_32.Impl)
  end
end

module Inputs_64 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        open Core_kernel

        type t = int64
        [@@deriving bin_io, eq, sexp, to_yojson, compare, version]
      end

      include T
    end
  end

  module Impl = struct
    let to_string = Int64.to_string

    let of_string = Int64.of_string

    let logand = Int64.logand

    let one = Int64.one

    let shift_right_logical = Int64.shift_right_logical

    let length_in_bits = 64
  end
end

module Make64 () = struct
  module Stable = struct
    module V1 = Make (Inputs_64.Stable.V1) (Inputs_64.Impl)
  end
end
