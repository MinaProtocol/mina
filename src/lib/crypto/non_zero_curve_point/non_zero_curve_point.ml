open Core_kernel
open Snark_params.Tick

let parity y = Bigint.(test_bit (of_field y) 0)

let gen_uncompressed =
  Quickcheck.Generator.filter_map Field.gen_uniform ~f:(fun x ->
      let open Option.Let_syntax in
      let%map y = Inner_curve.find_y x in
      (x, y) )

module Compressed = struct
  open Compressed_poly

  module Arg = struct
    (* module with same type t as Stable below, to build functor argument *)
    [%%versioned
    module Stable = struct
      module V1 = struct
        [@@@with_all_version_tags]

        type t = ((Field.t[@version_asserted]), bool) Poly.Stable.V1.t

        let to_latest = Fn.id
      end
    end]
  end

  let compress (x, y) = { Poly.x; is_odd = parity y }

  [%%versioned
  module Stable = struct
    module V1 = struct
      [@@@with_all_version_tags]

      module T = struct
        type t = ((Field.t[@version_asserted]), bool) Poly.Stable.V1.t
        [@@deriving equal, compare, hash]

        let to_latest = Fn.id

        module M = struct
          (* for compatibility with legacy Base58Check serialization *)
          include Arg.Stable.V1.With_all_version_tags

          let description = "Non zero curve point compressed"

          let version_byte =
            Base58_check.Version_bytes.non_zero_curve_point_compressed
        end

        module Base58 = Codable.Make_base58_check (M)
        include Base58

        (* sexp representation is a Base58Check string, like the yojson representation *)
        let sexp_of_t t = to_base58_check t |> Sexp.of_string

        let t_of_sexp sexp = Sexp.to_string sexp |> of_base58_check_exn
      end

      include T
      include Hashable.Make_binable (T)

      let gen =
        let open Quickcheck.Generator.Let_syntax in
        let%map uncompressed = gen_uncompressed in
        compress uncompressed
    end
  end]

  module Poly = Poly
  include Comparable.Make_binable (Stable.Latest)
  include Hashable.Make_binable (Stable.Latest)
  include Stable.Latest.Base58

  let to_string = to_base58_check

  [%%define_locally Stable.Latest.(sexp_of_t, t_of_sexp, gen)]

  let compress (x, y) = { Poly.x; is_odd = parity y }

  let empty = Poly.{ x = Field.zero; is_odd = false }

  let to_input { Poly.x; is_odd } =
    { Random_oracle.Input.Chunked.field_elements = [| x |]
    ; packeds = [| (Field.project [ is_odd ], 1) |]
    }

  let to_input_legacy { Poly.x; is_odd } =
    { Random_oracle.Input.Legacy.field_elements = [| x |]
    ; bitstrings = [| [ is_odd ] |]
    }

  (* snarky-dependent *)

  type var = (Field.Var.t, Boolean.var) Poly.t

  let typ : (var, t) Typ.t =
    Typ.of_hlistable [ Field.typ; Boolean.typ ] ~var_to_hlist:Poly.to_hlist
      ~var_of_hlist:Poly.of_hlist ~value_to_hlist:Poly.to_hlist
      ~value_of_hlist:Poly.of_hlist

  let var_of_t ({ x; is_odd } : t) : var =
    { x = Field.Var.constant x; is_odd = Boolean.var_of_value is_odd }

  let assert_equal (t1 : var) (t2 : var) =
    let%map () = Field.Checked.Assert.equal t1.x t2.x
    and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
    ()

  module Checked = struct
    let equal t1 t2 =
      let%bind x_eq = Field.Checked.equal t1.Poly.x t2.Poly.x in
      let%bind odd_eq = Boolean.equal t1.is_odd t2.is_odd in
      Boolean.(x_eq && odd_eq)

    let to_input ({ x; is_odd } : var) =
      { Random_oracle.Input.Chunked.field_elements = [| x |]
      ; packeds = [| ((is_odd :> Field.Var.t), 1) |]
      }

    let to_input_legacy = to_input_legacy

    let if_ cond ~then_:t1 ~else_:t2 =
      let%map x = Field.Checked.if_ cond ~then_:t1.Poly.x ~else_:t2.Poly.x
      and is_odd = Boolean.if_ cond ~then_:t1.is_odd ~else_:t2.is_odd in
      Poly.{ x; is_odd }

    module Assert = struct
      let equal t1 t2 =
        let%map () = Field.Checked.Assert.equal t1.Poly.x t2.Poly.x
        and () = Boolean.Assert.(t1.is_odd = t2.is_odd) in
        ()
    end
  end

  (* end snarky-dependent *)
end

module Uncompressed = struct
  let decompress ({ x; is_odd } : Compressed.t) =
    Option.map (Inner_curve.find_y x) ~f:(fun y ->
        let y_parity = parity y in
        let y = if Bool.(is_odd = y_parity) then y else Field.negate y in
        (x, y) )

  let decompress_exn t =
    match decompress t with
    | Some d ->
        d
    | None ->
        failwith
          (sprintf "Compressed public key %s could not be decompressed"
             (Yojson.Safe.to_string @@ Compressed.to_yojson t) )

  let of_base58_check_decompress_exn pk_str =
    let pk = Compressed.of_base58_check_exn pk_str in
    decompress_exn pk |> ignore ;
    pk

  let compress = Compressed.compress

  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      [@@@with_all_version_tags]

      type t = Field.t * Field.t [@@deriving compare, equal, hash]

      let to_latest = Fn.id

      include
        Binable.Of_binable_without_uuid
          (Compressed.Stable.V1)
          (struct
            type nonrec t = t

            let of_binable = decompress_exn

            let to_binable = compress
          end)

      let gen : t Quickcheck.Generator.t = gen_uncompressed

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
  end]

  (* so we can make sets of public keys *)
  include Comparable.Make_binable (Stable.Latest)

  [%%define_locally
  Stable.Latest.
    (of_bigstring, to_bigstring, sexp_of_t, t_of_sexp, to_yojson, of_yojson)]

  let gen : t Quickcheck.Generator.t = gen_uncompressed

  let ( = ) = equal

  let of_inner_curve_exn = Inner_curve.to_affine_exn

  let to_inner_curve = Inner_curve.of_affine

  let%test_unit "point-compression: decompress . compress = id" =
    Quickcheck.test gen ~f:(fun pk ->
        assert (equal (decompress_exn (compress pk)) pk) )

  (* snarky-dependent *)

  type var = Field.Var.t * Field.Var.t

  let assert_equal var1 var2 =
    let open Field.Checked.Assert in
    let v1_f1, v1_f2 = var1 in
    let v2_f1, v2_f2 = var2 in
    let%bind () = equal v1_f1 v2_f1 in
    let%map () = equal v1_f2 v2_f2 in
    ()

  let var_of_t (x, y) = (Field.Var.constant x, Field.Var.constant y)

  let typ : (var, t) Typ.t = Typ.(field * field)

  module Parity = struct
    (** [x < 2^num_bits], checked 16 bits per row with the EndoMulScalar gate.
        [num_bits] must be a multiple of 16.
    *)
    let range_check ~num_bits (x : Field.Var.t) =
      let open Run in
      let _, _, recomposed =
        Pickles.Scalar_challenge.to_field_checked' ~num_bits
          (module Run)
          (Kimchi_backend_common.Scalar_challenge.create x)
      in
      Field.Assert.equal recomposed x

    let limb_bits = 128

    let limb = Bignum_bigint.(pow (of_int 2) (of_int limb_bits))

    let field_of_bigint x = Bigint.to_field (Bigint.of_bignum_bigint x)

    let split_limbs x = Bignum_bigint.(x / limb, rem x limb)

    let p_minus_1_hi, p_minus_1_lo =
      split_limbs (Bigint.to_bignum_bigint (Bigint.of_field Field.(negate one)))

    (** The witness for [var]: [((hi, lo_div_2), odd), borrow]. *)
    type decomposition = ((Field.t * Field.t) * bool) * bool

    (** The decomposition of the integer [v] that [var] checks. *)
    let decomposition (v : Bignum_bigint.t) : decomposition =
      let hi, lo = split_limbs v in
      let open Bignum_bigint in
      ( ( (field_of_bigint hi, field_of_bigint (lo / of_int 2))
        , equal (rem lo (of_int 2)) one )
      , lo > p_minus_1_lo )

    type _ Snarky_backendless.Request.t +=
      | Decomposition : Field.t -> decomposition Snarky_backendless.Request.t

    (** The low bit of the canonical representative of [y] in [0, p).

        [y] is decomposed as [2^128 * hi + 2 * lo_div_2 + odd] with [hi] and
        [lo_div_2] range checked to 128 bits. That alone would admit [y + p],
        which has the opposite parity, so the decomposition is also checked to
        be at most [p - 1], by subtracting it from [p - 1] in 128-bit limbs with
        a borrow and range checking both differences: a negative difference
        would wrap around to near [p].
    *)
    let var (y : Field.Var.t) : Boolean.var Checked.t =
      make_checked (fun () ->
          let open Run in
          let two_to_limb = field_of_bigint limb in
          let ((hi, lo_div_2), odd), borrow =
            exists
              Typ.(Field.typ * Field.typ * Boolean.typ * Boolean.typ)
              ~request:(fun () -> Decomposition (As_prover.read_var y))
              ~compute:(fun () ->
                decomposition
                  (Bigint.to_bignum_bigint
                     (Bigint.of_field (As_prover.read_var y)) ) )
          in
          let lo = Field.(scale lo_div_2 (Constant.of_int 2) + (odd :> t)) in
          Field.Assert.equal y Field.(scale hi two_to_limb + lo) ;
          range_check ~num_bits:limb_bits hi ;
          range_check ~num_bits:limb_bits lo_div_2 ;
          let borrow = (borrow :> Field.t) in
          range_check ~num_bits:limb_bits
            Field.(
              constant (field_of_bigint p_minus_1_lo)
              - lo + scale borrow two_to_limb) ;
          range_check ~num_bits:limb_bits
            Field.(constant (field_of_bigint p_minus_1_hi) - hi - borrow) ;
          odd )
  end

  let parity_var = Parity.var

  let decompress_var ({ x; is_odd } as c : Compressed.var) =
    let open Let_syntax in
    let%bind y =
      exists Typ.field
        ~compute:
          As_prover.(
            map (read Compressed.typ c) ~f:(fun c -> snd (decompress_exn c)))
    in
    let%map () = Inner_curve.Checked.Assert.on_curve (x, y)
    and () = parity_var y >>= Boolean.Assert.(( = ) is_odd) in
    (x, y)

  let%snarkydef_ compress_var ((x, y) : var) : Compressed.var Checked.t =
    let open Compressed_poly in
    let%map is_odd = parity_var y in
    { Poly.x; is_odd }

  (* end snarky-dependent *)
end

include Uncompressed

let%test_module "parity_var" =
  ( module struct
    let check y =
      Test.test_equal ~sexp_of_t:[%sexp_of: bool] ~equal:Bool.equal Typ.field
        Boolean.typ parity_var parity y

    let two_to n = Fn.apply_n_times ~n (fun x -> Field.(x + x)) Field.one

    let%test_unit "agrees with parity on random field elements" =
      Quickcheck.test ~trials:100 Field.gen ~f:check

    (** Whether [parity_var y] is satisfiable with the decomposition of the
        integer [v] as its witness. *)
    let satisfiable_with ~(v : unit -> Parity.decomposition) y =
      Or_error.is_ok
        (Snark_params.Tick.check
           (Snark_params.Tick.handle
              (fun () ->
                let%bind y = exists Typ.field ~compute:(As_prover.return y) in
                parity_var y )
              (fun (With { request; respond }) ->
                match request with
                | Parity.Decomposition _ ->
                    respond (Provide (v ()))
                | _ ->
                    respond Unhandled ) ) )

    let%test_unit "rejects non-canonical decompositions" =
      let p = Field.size in
      Quickcheck.test ~trials:20 Field.gen ~f:(fun y ->
          let y_int = Bigint.to_bignum_bigint (Bigint.of_field y) in
          assert (satisfiable_with y ~v:(fun () -> Parity.decomposition y_int)) ;
          List.iter [ 1; 2 ] ~f:(fun k ->
              let v = Bignum_bigint.(y_int + (of_int k * p)) in
              let ((hi, lo_div_2), odd), _ = Parity.decomposition v in
              List.iter [ false; true ] ~f:(fun borrow ->
                  if
                    satisfiable_with y ~v:(fun () ->
                        (((hi, lo_div_2), odd), borrow) )
                  then failwithf "y + %dp accepted (borrow %b)" k borrow () ) ) )

    let%test_unit "agrees with parity at boundaries" =
      let p_minus k = Field.(negate (of_int k)) in
      List.iter ~f:check
        ( List.map [ 0; 1; 2; 3 ] ~f:Field.of_int
        @ List.map [ 1; 2; 3; 4 ] ~f:p_minus
        @ List.concat_map [ 128; 254 ] ~f:(fun n ->
              [ Field.(two_to n - one); two_to n; Field.(two_to n + one) ] )
        @ List.map [ -1; 0; 1; 2 ] ~f:(fun k ->
              Field.(p_minus 1 - two_to 128 + of_int k) ) )
  end )
