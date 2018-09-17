open Bin_prot.Std
open Sexplib.Std

module type Input_intf = sig
  type t [@@deriving bin_io, eq, sexp]

  val length_in_bits : int

  val one : t

  val logand : t -> t -> t

  val shift_right_logical : t -> int -> t
end

module Make (M : Input_intf) = struct
  include M

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
end

module Make32 () = Make (struct
  type t = int32 [@@deriving bin_io, eq, sexp]

  let logand = Int32.logand

  let one = Int32.one

  let shift_right_logical = Int32.shift_right_logical

  let length_in_bits = 32
end)

module Make64 () = Make (struct
  type t = int64 [@@deriving bin_io, eq, sexp]

  let logand = Int64.logand

  let one = Int64.one

  let shift_right_logical = Int64.shift_right_logical

  let length_in_bits = 64
end)
