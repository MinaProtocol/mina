module type Input_intf = sig
  type t [@@deriving bin_io, eq, sexp, compare, version]

  include Base.Stringable.S with type t := t

  val length_in_bits : int

  val one : t

  val zero : t

  val logand : t -> t -> t

  val shift_right_logical : t -> int -> t
end

module Make (M : Input_intf) = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = M.t [@@deriving bin_io, eq, sexp, compare, version]
      end

      include T
    end

    module Latest = V1
  end

  type t = Stable.Latest.t [@@deriving eq, sexp, compare]

  let length_in_triples = (M.length_in_bits + 2) / 3

  let fold t : bool Fold_lib.Fold.t =
    { fold=
        (fun ~init ~f ->
          let rec go acc pt i =
            if i = M.length_in_bits then acc
            else
              let b = M.(equal (logand one pt) one) in
              go (f acc b) (M.shift_right_logical pt 1) (i + 1)
          in
          go init t 0 ) }

  let fold t = Fold_lib.Fold.group3 ~default:false (fold t)

  module Importable = struct
    type t = Stable.Latest.t [@@deriving eq, sexp, compare]

    let length_in_triples, fold = (length_in_triples, fold)
  end
end

module Input_32_V1 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Core_kernel.Int32.t
        [@@deriving bin_io, eq, sexp, compare, version {asserted}]
      end

      include T
    end
  end

  include Stable.V1

  let to_string = Int32.to_string

  let of_string = Int32.of_string

  let logand = Int32.logand

  let one = Int32.one

  let zero = Int32.zero

  let shift_right_logical = Int32.shift_right_logical

  let length_in_bits = 32
end

module V1_32_make () = Make (Input_32_V1)

module Inputs_64_V1 = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Core_kernel.Int64.t
        [@@deriving bin_io, eq, sexp, compare, version {asserted}]
      end

      include T
    end
  end

  include Stable.V1

  let to_string = Int64.to_string

  let of_string = Int64.of_string

  let logand = Int64.logand

  let one = Int64.one

  let zero = Int64.zero

  let shift_right_logical = Int64.shift_right_logical

  let length_in_bits = 64
end

module V1_64_make () = Make (Inputs_64_V1)
