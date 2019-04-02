open Core_kernel
open Snark_params
open Fold_lib
open Module_version

module Codable_via_base64 (T : sig
  type t [@@deriving bin_io]
end) =
struct
  let to_base64 t = Binable.to_string (module T) t |> Base64.encode_string

  let of_base64_exn s = Base64.decode_exn s |> Binable.of_string (module T)

  module String_ops = struct
    type t = T.t

    let to_string = to_base64

    let of_string = of_base64_exn
  end

  include Codable.Make_of_string (String_ops)
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Tick.Field.t * Tick.Field.t
      [@@deriving bin_io, sexp, eq, compare, hash, version]
    end

    include T
    include Registration.Make_latest_version (T)

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

    include Codable_via_base64 (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "non_zero_curve_point"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io omitted *)
type t = Stable.Latest.t [@@deriving sexp, compare, hash]

(* so we can make sets of public keys *)
include Comparable.Make_binable (Stable.Latest)

type var = Tick.Field.Var.t * Tick.Field.Var.t

let var_of_t (x, y) = (Tick.Field.Var.constant x, Tick.Field.Var.constant y)

let typ : (var, t) Tick.Typ.t = Tick.Typ.(field * field)

let ( = ) = equal

let of_inner_curve_exn = Tick.Inner_curve.to_affine_coordinates

let to_inner_curve = Tick.Inner_curve.of_affine_coordinates

let gen : t Quickcheck.Generator.t =
  Quickcheck.Generator.filter_map Tick.Field.gen ~f:(fun x ->
      let open Option.Let_syntax in
      let%map y = Tick.Inner_curve.find_y x in
      (x, y) )

let parity y = Tick.Bigint.(test_bit (of_field y) 0)

module Compressed = struct
  open Tick

  module Poly = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('field, 'boolean) t = {x: 'field; is_odd: 'boolean}
          [@@deriving bin_io, sexp, compare, eq, hash, version]
        end

        include T
      end

      module Latest = V1
    end
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        type t = (Field.t, bool) Poly.Stable.V1.t
        [@@deriving bin_io, sexp, eq, compare, hash, version]
      end

      include T
      include Registration.Make_latest_version (T)
      include Codable_via_base64 (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "non_zero_curve_point_compressed"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io omitted *)
  type t = Stable.Latest.t [@@deriving sexp, compare, hash]

  include Comparable.Make_binable (Stable.Latest)
  include Hashable.Make_binable (Stable.Latest)
  include Codable_via_base64 (Stable.Latest)

  let compress (x, y) : t = {x; is_odd= parity y}

  let to_string = to_base64

  let empty = Poly.Stable.Latest.{x= Field.zero; is_odd= false}

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map x = Field.gen and is_odd = Bool.gen in
    Poly.Stable.Latest.{x; is_odd}

  let bit_length_to_triple_length n = (n + 2) / 3

  let length_in_triples = bit_length_to_triple_length (1 + Field.size_in_bits)

  type var = (Field.Var.t, Boolean.var) Poly.Stable.Latest.t

  let to_hlist Poly.Stable.Latest.({x; is_odd}) = Snarky.H_list.[x; is_odd]

  let of_hlist :
      (unit, 'a -> 'b -> unit) Snarky.H_list.t -> ('a, 'b) Poly.Stable.Latest.t
      =
    Snarky.H_list.(fun [x; is_odd] -> {x; is_odd})

  let typ : (var, t) Typ.t =
    Typ.of_hlistable
      Data_spec.[Field.typ; Boolean.typ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let var_of_t ({x; is_odd} : t) : var =
    {x= Field.Var.constant x; is_odd= Boolean.var_of_value is_odd}

  let assert_equal (t1 : var) (t2 : var) =
    let%map () = Field.Checked.Assert.equal t1.x t2.x
    and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
    ()

  let fold_bits Poly.Stable.Latest.({is_odd; x}) =
    {Fold.fold= (fun ~init ~f -> f ((Field.Bits.fold x).fold ~init ~f) is_odd)}

  let fold t = Fold.group3 ~default:false (fold_bits t)

  (* TODO: Right now everyone could switch to using the other unpacking...
   Either decide this is ok or assert bitstring lt field size *)
  let var_to_triples ({x; is_odd} : var) =
    let%map x_bits =
      Field.Checked.choose_preimage_var x ~length:Field.size_in_bits
    in
    Bitstring_lib.Bitstring.pad_to_triple_list
      (x_bits @ [is_odd])
      ~default:Boolean.false_

  module Checked = struct
    let equal t1 t2 =
      let%bind x_eq =
        Field.Checked.equal t1.Poly.Stable.Latest.x t2.Poly.Stable.Latest.x
      in
      let%bind odd_eq = Boolean.equal t1.is_odd t2.is_odd in
      Boolean.(x_eq && odd_eq)

    let if_ cond ~then_:t1 ~else_:t2 =
      let%map x =
        Field.Checked.if_ cond ~then_:t1.Poly.Stable.Latest.x
          ~else_:t2.Poly.Stable.Latest.x
      and is_odd = Boolean.if_ cond ~then_:t1.is_odd ~else_:t2.is_odd in
      Poly.Stable.Latest.{x; is_odd}

    module Assert = struct
      let equal t1 t2 =
        let%map () =
          Field.Checked.Assert.equal t1.Poly.Stable.Latest.x
            t2.Poly.Stable.Latest.x
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
    exists Typ.field
      ~compute:
        As_prover.(
          map (read Compressed.typ c) ~f:(fun c -> snd (decompress_exn c)))
  in
  let%map () = Inner_curve.Checked.Assert.on_curve (x, y)
  and () = parity_var y >>= Boolean.Assert.(( = ) is_odd) in
  (x, y)

let compress : t -> Compressed.t = Compressed.compress

let%snarkydef compress_var ((x, y) : var) : (Compressed.var, _) Checked.t =
  let%map is_odd = parity_var y in
  {Compressed.Poly.Stable.Latest.x; is_odd}

let of_bigstring, to_bigstring = Stable.Latest.(of_bigstring, to_bigstring)

let%test_unit "point-compression: decompress . compress = id" =
  Quickcheck.test gen ~f:(fun pk ->
      assert (equal (decompress_exn (compress pk)) pk) )
