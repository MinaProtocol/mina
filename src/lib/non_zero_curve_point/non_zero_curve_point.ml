open Core_kernel
open Snark_params
open Fold_lib

module Stable = struct
  module V1 = struct
    type t = Tick.Field.t * Tick.Field.t
    [@@deriving bin_io, sexp, eq, compare, hash]
  end
end

include Stable.V1
include Comparable.Make_binable (Stable.V1)

type var = Tick.Field.var * Tick.Field.var

let var_of_t (x, y) =
  (Tick.Field.Checked.constant x, Tick.Field.Checked.constant y)

let typ : (var, t) Tick.Typ.t = Tick.Typ.(field * field)

let ( = ) = equal

let of_inner_curve_exn = Tick.Inner_curve.to_coords

let to_inner_curve = Tick.Inner_curve.of_coords

let gen : t Quickcheck.Generator.t =
  Quickcheck.Generator.filter_map Tick.Field.gen ~f:(fun x ->
      let open Option.Let_syntax in
      let%map y = Tick.Inner_curve.find_y x in
      (x, y) )

let parity y = Tick.Bigint.(test_bit (of_field y) 0)

module Compressed = struct
  open Tick

  type ('field, 'boolean) t_ = {x: 'field; is_odd: 'boolean}
  [@@deriving bin_io, sexp, compare, eq, hash]

  module Stable = struct
    module V1 = struct
      type t = (Field.t, bool) t_ [@@deriving bin_io, sexp, eq, compare, hash]
    end
  end

  include Stable.V1
  include Comparable.Make_binable (Stable.V1)
  include Hashable.Make_binable (Stable.V1)

  let compress (x, y) : t = {x; is_odd= parity y}

  let to_base64 t = Binable.to_string (module Stable.V1) t |> B64.encode

  let of_base64_exn s = B64.decode s |> Binable.of_string (module Stable.V1)

  let empty = {x= Field.zero; is_odd= false}

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map x = Field.gen and is_odd = Bool.gen in
    {x; is_odd}

  let bit_length_to_triple_length n = (n + 2) / 3

  let length_in_triples = bit_length_to_triple_length (1 + Field.size_in_bits)

  type var = (Field.var, Boolean.var) t_

  let to_hlist {x; is_odd} = Snarky.H_list.[x; is_odd]

  let of_hlist : (unit, 'a -> 'b -> unit) Snarky.H_list.t -> ('a, 'b) t_ =
    Snarky.H_list.(fun [x; is_odd] -> {x; is_odd})

  let typ : (var, t) Typ.t =
    Typ.of_hlistable
      Data_spec.[Field.typ; Boolean.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let var_of_t ({x; is_odd} : t) : var =
    {x= Field.Checked.constant x; is_odd= Boolean.var_of_value is_odd}

  let assert_equal (t1 : var) (t2 : var) =
    let open Let_syntax in
    let%map () = Field.Checked.Assert.equal t1.x t2.x
    and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
    ()

  let fold_bits {is_odd; x} =
    {Fold.fold= (fun ~init ~f -> f ((Field.Bits.fold x).fold ~init ~f) is_odd)}

  let fold t = Fold.group3 ~default:false (fold_bits t)

  (* TODO: Right now everyone could switch to using the other unpacking...
   Either decide this is ok or assert bitstring lt field size *)
  let var_to_triples ({x; is_odd} : var) =
    let open Let_syntax in
    let%map x_bits =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits
    in
    Bitstring_lib.Bitstring.pad_to_triple_list
      (x_bits @ [is_odd])
      ~default:Boolean.false_

  module Checked = struct
    open Let_syntax

    let equal t1 t2 =
      let%bind x_eq = Field.Checked.equal t1.x t2.x in
      let%bind odd_eq = Boolean.equal t1.is_odd t2.is_odd in
      Boolean.(x_eq && odd_eq)

    module Assert = struct
      let equal t1 t2 =
        let%map () = Field.Checked.Assert.equal t1.x t2.x
        and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
        ()
    end
  end
end

open Tick
open Let_syntax

let decompress ({x; is_odd} : Compressed.t) =
  Option.map (Tick.Inner_curve.find_y x) ~f:(fun y ->
      let y_parity = parity y in
      let y = if Bool.(is_odd = y_parity) then y else Field.negate y in
      (x, y) )

let decompress_exn t = Option.value_exn (decompress t)

let parity_var y =
  let%map bs = Field.Checked.unpack_full y in
  List.hd_exn (Bitstring_lib.Bitstring.Lsb_first.to_list bs)

let decompress_var ({x; is_odd} as c : Compressed.var) =
  let%bind y =
    provide_witness Typ.field
      As_prover.(
        map (read Compressed.typ c) ~f:(fun c -> snd (decompress_exn c)))
  in
  let%map () = Inner_curve.Checked.Assert.on_curve (x, y)
  and () = parity_var y >>= Boolean.Assert.(( = ) is_odd) in
  (x, y)

let compress : t -> Compressed.t = Compressed.compress

let compress_var ((x, y) : var) : (Compressed.var, _) Checked.t =
  with_label __LOC__
    (let%map is_odd = parity_var y in
     {Compressed.x; is_odd})

let of_bigstring bs =
  let open Or_error.Let_syntax in
  let%map elem, _ = Bigstring.read_bin_prot bs bin_reader_t in
  elem

let to_bigstring elem =
  let bs =
    Bigstring.create (bin_size_t elem + Bin_prot.Utils.size_header_length)
  in
  let _ = Bigstring.write_bin_prot bs bin_writer_t elem in
  bs

let%test_unit "point-compression: decompress . compress = id" =
  Quickcheck.test gen ~f:(fun pk ->
      assert (equal (decompress_exn (compress pk)) pk) )
