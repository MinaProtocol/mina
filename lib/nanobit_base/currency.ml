open Core
open Snark_params
open Tick
open Let_syntax

module Make_bin_io
    (M : sig
       type v
       type t
       val bin_t : t Bin_prot.Type_class.t
       val there : v -> t
       val back : t -> v
     end) = struct

  let ({ Bin_prot.Type_class.
          reader = bin_reader_t
        ; writer = bin_writer_t
        ; shape = bin_shape_t
        } as bin_t)
    =
    Bin_prot.Type_class.cnv Fn.id M.there M.back M.bin_t

  let { Bin_prot.Type_class.read = bin_read_t; vtag_read = __bin_read_t__ } = bin_reader_t
  let { Bin_prot.Type_class.write = bin_write_t; size = bin_size_t } = bin_writer_t
end

module type Basic = sig
  type t
  [@@deriving sexp, compare, eq, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, compare, eq, hash]
    end
  end

  include Bits_intf.S with type t := t

  val zero : t

  val of_string : string -> t
  val to_string : t -> string

  type var
  val typ : (var, t) Typ.t

  val of_int : int -> t

  val var_of_t : t -> var

  val var_to_bits : var -> Boolean.var list
end

module type S = sig
  include Basic

  val add : t -> t -> t option
  val sub : t -> t -> t option
  val (+) : t -> t -> t option
  val (-) : t -> t -> t option

  module Checked : sig
    val add : var -> var -> (var, _) Checked.t
    val sub : var -> var -> (var, _) Checked.t
    val (+) : var -> var -> (var, _) Checked.t
    val (-) : var -> var -> (var, _) Checked.t
  end
end

module Make
    (Unsigned : Unsigned.S)
    (Signed : sig type t [@@deriving bin_io] end)
    (M : sig
       val to_signed : Unsigned.t -> Signed.t
       val of_signed : Signed.t -> Unsigned.t
       val length : int
     end)
    : S with type t = Unsigned.t
= struct
  assert (M.length < Tick.Field.size_in_bits - 3)

  module Stable = struct
    module V1 = struct
      module T = struct
        include Sexpable.Of_stringable(Unsigned)
        type t = Unsigned.t

        let compare = Unsigned.compare
        let equal t1 t2 = compare t1 t2 = 0

        let hash_fold_t s t = Int64.hash_fold_t s (Unsigned.to_int64 t)
        let hash t = Int64.hash (Unsigned.to_int64 t)
      end
      include T
      include Hashable.Make(T)

      include Make_bin_io(struct
          type v = Unsigned.t
          type t = Signed.t [@@deriving bin_io]
          let there = M.to_signed
          let back = M.of_signed
        end)
    end
  end

  include Stable.V1
  include Sexpable.Of_stringable(Unsigned)
  let of_string = Unsigned.of_string
  let to_string = Unsigned.to_string

  let of_int = Unsigned.of_int
  let of_string = Unsigned.of_string
  let to_string = Unsigned.to_string

  module Vector = struct
    include M
    include Unsigned
    let empty = zero
    let get t i = Infix.((t lsr i) land one = one)
    let set v i b =
      if b
      then Infix.(v lor (one lsl i))
      else Infix.(v land (lognot (one lsl i)))
  end

  include (Bits.Vector.Make(Vector) : Bits_intf.S with type t := t)

  include Bits.Snarkable.Small_bit_vector(Tick)(Vector)

  include Unpacked

  let zero = Unsigned.zero

  let sub x y =
    if compare x y < 0
    then None
    else Some (Unsigned.sub x y)

  let add x y =
    let z = Unsigned.add x y in
    if compare z x < 0
    then None
    else Some z

  let (+) = add
  let (-) = sub

  let var_of_t t =
    List.init (M.length) (fun i -> Boolean.var_of_value (Vector.get t i))

  module Checked = struct
    (* Unpacking protects against underflow *)
    let sub (x : Unpacked.var) (y : Unpacked.var) =
      unpack_var (Cvar.sub (pack_var x) (pack_var y))

    (* Unpacking protects against overflow *)
    let add (x : Unpacked.var) (y : Unpacked.var) =
      unpack_var (Cvar.add (pack_var x) (pack_var y))

      let check c =
        let ((), (), passed) =
          run_and_check (Checked.map c ~f:(fun _ -> As_prover.return ())) ()
        in
        passed

      let expect_failure err c = (if check c then failwith err)
      let expect_success err c = (if not (check c) then failwith err)

      let to_bigint x =
        Bignum.Bigint.of_string (Unsigned.to_string x)

      let of_bigint x =
        Unsigned.of_string (Bignum.Bigint.to_string x)

      let gen_incl x y =
        Quickcheck.Generator.map ~f:of_bigint
          (Bignum.Bigint.gen_incl (to_bigint x) (to_bigint y))

      let%test_unit "subtraction_completeness" =
        let generator =
          let open Quickcheck.Generator.Let_syntax in
          let%bind x = gen_incl Unsigned.zero Unsigned.max_int in
          let%map y = gen_incl Unsigned.zero x in
          (x, y)
        in
        Quickcheck.test generator ~f:(fun (lo, hi) ->
          expect_success
            (sprintf !"subtraction: lo=%{Unsigned} hi=%{Unsigned}" lo hi)
            (of_t lo - of_t hi))

      let%test_unit "subtraction_soundness" =
        let generator =
          let open Quickcheck.Generator.Let_syntax in
          let%bind x = gen_incl Unsigned.zero Unsigned.(sub max_int one) in
          let%map y = gen_incl Unsigned.(add x one) Unsigned.max_int in
          (x, y)
        in
        Quickcheck.test generator ~f:(fun (lo, hi) ->
          expect_failure
            (sprintf !"underflow: lo=%{Unsigned} hi=%{Unsigned}" lo hi)
            (of_t lo - of_t hi))

      let%test_unit "addition_completeness" =
        let generator =
          let open Quickcheck.Generator.Let_syntax in
          let%bind x = gen_incl Unsigned.zero Unsigned.max_int in
          let%map y = gen_incl Unsigned.zero Unsigned.(sub max_int x) in
          (x, y)
        in
        Quickcheck.test generator ~f:(fun (x, y) ->
          expect_success
            (sprintf !"overflow: x=%{Unsigned} y=%{Unsigned}" x y)
            (of_t x + of_t y))

      let%test_unit "addition_soundness" =
        let generator =
          let open Quickcheck.Generator.Let_syntax in
          let%bind x = gen_incl Unsigned.one Unsigned.max_int in
          let%map y = gen_incl Unsigned.(add (sub max_int x) one) Unsigned.max_int in
          (x, y)
        in
        Quickcheck.test generator ~f:(fun (x, y) ->
          expect_failure
            (sprintf !"overflow: x=%{Unsigned} y=%{Unsigned}" x y)
            (of_t x + of_t y))
    end)
end

module Amount = Make(Unsigned.UInt64)(Int64)(struct
    let length = 64
    let to_signed = Unsigned.UInt64.to_int64
    let of_signed = Unsigned.UInt64.of_int64
  end)

module Fee = Make(Unsigned.UInt32)(Int32)(struct
    let length = 32
    let to_signed = Unsigned.UInt32.to_int32
    let of_signed = Unsigned.UInt32.of_int32
  end)

module Balance = struct
  include (Amount : Basic with type t = Amount.t and type var = Amount.var)

  let add_amount = Amount.add
  let sub_amount = Amount.sub
  let (+) = add_amount
  let (-) = sub_amount

  module Checked = struct
    let add_amount = Amount.Checked.add
    let sub_amount = Amount.Checked.sub
    let (+) = add_amount
    let (-) = sub_amount
  end
end
