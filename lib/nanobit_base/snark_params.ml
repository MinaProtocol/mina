open Core_kernel

type functionalities =
  { strength_calculation : bool
  ; verify_blockchain    : bool
  ; compute_base_hash    : bool
  ; compute_base_proof   : bool
  ; extend_blockchain    : bool
  ; check_target         : bool
  }

(* These should all be false. *)
let insecure_functionalities =
  { strength_calculation = true
  ; verify_blockchain = true
  ; compute_base_hash = false
  ; compute_base_proof = false
  ; extend_blockchain = false
  ; check_target = true
  }

module Tick_curve = Camlsnark.Backends.Mnt4
module Tock_curve = Camlsnark.Backends.Mnt6

module Extend (Impl : Camlsnark.Snark_intf.S) = struct
  include Impl

  module Snarkable = struct
    module type S = sig
      type var
      type value
      val spec : (var, value) Var_spec.t
    end

    module Bits = struct
      module type S = Bits_intf.Snarkable
        with type ('a, 'b) var_spec := ('a, 'b) Var_spec.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
    end
  end
end

module Tock = Extend(Camlsnark.Snark.Make(Tock_curve))

module Tick = struct
  module Tick0 = Extend(Camlsnark.Snark.Make(Tick_curve))

  include (Tick0 : module type of Tick0 with module Field := Tick0.Field)

  module Field = struct
    include Tick0.Field

    include Field_bin.Make(Tick0.Field)(Tick_curve.Bigint.R)

    let rec compare_bitstring xs0 ys0 =
      match xs0, ys0 with
      | true :: xs, true :: ys | false :: xs, false :: ys -> compare_bitstring xs ys
      | false :: xs, true :: ys -> `LT
      | true :: xs, false :: ys -> `GT
      | [], [] -> `EQ
      | _ :: _, [] | [], _ :: _ -> failwith "compare_bitstrings: Different lengths"

    let () = 
      let main_size_proxy = List.rev (unpack (negate one)) in
      let other_size_proxy = List.rev Tock.Field.(unpack (negate one)) in
      assert (compare_bitstring main_size_proxy other_size_proxy = `LT)
  end

  module Pedersen = struct
    module Curve = struct
      (* someday: Compute this from the number inside of ocaml *)
      let bit_length = 262

      include Camlsnark.Curves.Edwards.Basic.Make(Field)(struct
          (*
  Curve params:
  d = 20
  cardinality = 475922286169261325753349249653048451545124878135421791758205297448378458996221426427165320
  2^3 * 5 * 7 * 399699743 * 4252498232415687930110553454452223399041429939925660931491171303058234989338533 *)

          let d = Field.of_int 20
          let cofactor = 8 * 5 * 7 * 399699743 
          let generator = 
            let f s = Tick_curve.Bigint.R.(to_field (of_decimal_string s)) in
            f "327139552581206216694048482879340715614392408122535065054918285794885302348678908604813232",
            f "269570906944652130755537879906638127626718348459103982395416666003851617088183934285066554"
        end)

      module Scalar (Impl : Camlsnark.Snark_intf.S) = struct
        (* Someday: Make more efficient *)
        open Impl
        type var = Boolean.var list
        type value = bool list

        let length = bit_length
        let spec : (var, value) Var_spec.t = Var_spec.list ~length Boolean.spec
        let assert_equal = Checked.Assert.equal_bitstrings
      end
    end

    module P = Pedersen.Make(Field)(Tick_curve.Bigint.R)(Curve)
    include (P : module type of P with module Digest := P.Digest)
    module Digest = struct
      include P.Digest
      include Snarkable(Tick0)
    end

    let params =
      let f s =
        Tick_curve.Bigint.R.(to_field (of_decimal_string s))
      in
      Array.map Pedersen_params.t ~f:(fun (x, y) -> (f x, f y))

    let hash_bigstring x : Digest.t =
      let s = State.create params in
      State.update_bigstring s x
      |> State.digest
    ;;

    let zero_hash = hash_bigstring (Bigstring.create 0)
  end

  module Scalar = Pedersen.Curve.Scalar(Tick0)

  module Hash_curve =
    Camlsnark.Curves.Edwards.Extend
      (Tick0)
      (Scalar)
      (Pedersen.Curve)

  module Pedersen_hash = Camlsnark.Pedersen.Make(Tick0)(struct
      include Hash_curve
      let cond_add = Checked.cond_add
    end)

  let hash_digest x =
    let open Checked in
    Pedersen_hash.hash x
      ~params:Pedersen.params
      ~init:Hash_curve.Checked.identity
    >>| Pedersen_hash.digest

  module Util = Snark_util.Make(Tick0)
end
