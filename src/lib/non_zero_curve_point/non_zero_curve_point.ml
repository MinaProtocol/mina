open Core_kernel
open Snark_params
open Fold_lib
open Module_version

let parity y = Tick.Bigint.(test_bit (of_field y) 0)

module Compressed = struct
  open Tick

  module Poly = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type ('field, 'boolean) t = {x: 'field; is_odd: 'boolean}
          [@@deriving bin_io, compare, eq, hash, version]
        end

        include T
      end

      module Latest = V1
    end

    type ('field, 'boolean) t = ('field, 'boolean) Stable.Latest.t =
      {x: 'field; is_odd: 'boolean}
    [@@deriving compare, eq, hash]
  end

  module Stable = struct
    module V1 = struct
      module T = struct
        (* we define sexp operations manually, don't derive them *)
        type t = (Field.t, bool) Poly.Stable.V1.t
        [@@deriving bin_io, eq, compare, hash, version {asserted}]
      end

      include T
      module Registered = Registration.Make_latest_version (T)
      include Registered

      let description = "Non zero curve point compressed"

      let version_byte =
        Base58_check.Version_bytes.non_zero_curve_point_compressed

      (* Registered contains shadowed versions of bin_io functions in T;
	 we call the same functor below with Stable.Latest, which also has
	 the shadowed versions
       *)
      include Codable.Make_base58_check (struct
        type nonrec t = t

        include Registered

        let description = description

        let version_byte = version_byte
      end)

      (* sexp representation is a Base58Check string, like the yojson representation *)
      let sexp_of_t t = to_base58_check t |> Sexp.of_string

      let t_of_sexp sexp = Sexp.to_string sexp |> of_base58_check_exn
    end

    module Latest = V1

    module Module_decl = struct
      let name = "non_zero_curve_point_compressed"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  (* bin_io, sexp omitted *)
  type t = (Field.t, bool) Poly.Stable.V1.t [@@deriving compare, hash]

  include Comparable.Make_binable (Stable.Latest)
  include Hashable.Make_binable (Stable.Latest)
  include Codable.Make_base58_check (Stable.Latest)

  [%%define_locally
  Stable.Latest.(sexp_of_t, t_of_sexp)]

  let compress (x, y) : t = {x; is_odd= parity y}

  let to_string = to_base58_check

  let empty = Poly.{x= Field.zero; is_odd= false}

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map x = Field.gen and is_odd = Bool.quickcheck_generator in
    Poly.{x; is_odd}

  let bit_length_to_triple_length n = (n + 2) / 3

  let length_in_triples = bit_length_to_triple_length (1 + Field.size_in_bits)

  type var = (Field.Var.t, Boolean.var) Poly.t

  let to_hlist Poly.Stable.Latest.{x; is_odd} = Snarky.H_list.[x; is_odd]

  let of_hlist : (unit, 'a -> 'b -> unit) Snarky.H_list.t -> ('a, 'b) Poly.t =
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

  let fold_bits Poly.{is_odd; x} =
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
      let%bind x_eq = Field.Checked.equal t1.Poly.x t2.Poly.x in
      let%bind odd_eq = Boolean.equal t1.is_odd t2.is_odd in
      Boolean.(x_eq && odd_eq)

    let if_ cond ~then_:t1 ~else_:t2 =
      let%map x = Field.Checked.if_ cond ~then_:t1.Poly.x ~else_:t2.Poly.x
      and is_odd = Boolean.if_ cond ~then_:t1.is_odd ~else_:t2.is_odd in
      Poly.{x; is_odd}

    module Assert = struct
      let equal t1 t2 =
        let%map () = Field.Checked.Assert.equal t1.Poly.x t2.Poly.x
        and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
        ()
    end
  end
end

let decompress ({x; is_odd} : Compressed.t) =
  Option.map (Tick.Inner_curve.find_y x) ~f:(fun y ->
      let y_parity = parity y in
      let y = if Bool.(is_odd = y_parity) then y else Tick.Field.negate y in
      (x, y) )

let compress = Compressed.compress

let decompress_exn t = Option.value_exn (decompress t)

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        Tick.Field.t * Tick.Field.t
        (* sexp operations written manually, don't derive them *)
      [@@deriving eq, compare, hash, version {asserted}]

      include Binable.Of_binable
                (Compressed.Stable.V1)
                (struct
                  type nonrec t = t

                  let of_binable = decompress_exn

                  let to_binable = compress
                end)
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

    (* We reuse the Base58check-based yojson (de)serialization from the
       compressed representation. *)
    let of_yojson json =
      let open Result in
      Compressed.of_yojson json
      >>= fun compressed ->
      Result.of_option ~error:"couldn't decompress, curve point invalid"
        (decompress compressed)

    let to_yojson t = Compressed.to_yojson @@ compress t

    (* as for yojson, use the Base58check-based sexps from the compressed representation *)
    let sexp_of_t t = Compressed.sexp_of_t @@ compress t

    let t_of_sexp sexp =
      Option.value_exn (decompress @@ Compressed.t_of_sexp sexp)
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
type t = Stable.Latest.t [@@deriving compare, hash, yojson]

(* so we can make sets of public keys *)
include Comparable.Make_binable (Stable.Latest)

type var = Tick.Field.Var.t * Tick.Field.Var.t

let assert_equal var1 var2 =
  let open Tick0.Checked.Let_syntax in
  let open Tick.Field.Checked.Assert in
  let v1_f1, v1_f2 = var1 in
  let v2_f1, v2_f2 = var2 in
  let%bind () = equal v1_f1 v2_f1 in
  let%bind () = equal v1_f2 v2_f2 in
  return ()

let var_of_t (x, y) = (Tick.Field.Var.constant x, Tick.Field.Var.constant y)

let typ : (var, t) Tick.Typ.t = Tick.Typ.(field * field)

let ( = ) = equal

let of_inner_curve_exn = Tick.Inner_curve.to_affine_exn

let to_inner_curve = Tick.Inner_curve.of_affine

let gen : t Quickcheck.Generator.t =
  Quickcheck.Generator.filter_map Tick.Field.gen ~f:(fun x ->
      let open Option.Let_syntax in
      let%map y = Tick.Inner_curve.find_y x in
      (x, y) )

open Tick
open Let_syntax

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

let%snarkydef compress_var ((x, y) : var) : (Compressed.var, _) Checked.t =
  let%map is_odd = parity_var y in
  {Compressed.Poly.x; is_odd}

[%%define_locally
Stable.Latest.(of_bigstring, to_bigstring, sexp_of_t, t_of_sexp)]

let%test_unit "point-compression: decompress . compress = id" =
  Quickcheck.test gen ~f:(fun pk ->
      assert (equal (decompress_exn (compress pk)) pk) )
