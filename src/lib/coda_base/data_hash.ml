(* data_hash.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Snark_params.Tick
open Bitstring_lib

[%%else]

open Snark_params_nonconsensus
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module type Full_size = Data_hash_intf.Full_size

module Make_basic (M : sig
  val length_in_bits : int
end) =
struct
  type t = Field.t [@@deriving sexp, compare, hash]

  let to_decimal_string (t : Field.t) = Field.to_string t

  let to_bytes t =
    Fold_lib.(Fold.bool_t_to_string (Fold.of_list (Field.unpack t)))

  let length_in_bits = M.length_in_bits

  let () = assert (Int.(length_in_bits <= Field.size_in_bits))

  let to_input t = Random_oracle.Input.field t

  [%%ifdef
  consensus_mechanism]

  (* this is in consensus code, because Bigint comes
     from snarky functors
  *)
  let gen : t Quickcheck.Generator.t =
    let m =
      if Int.(length_in_bits = Field.size_in_bits) then
        Bignum_bigint.(Field.size - one)
      else Bignum_bigint.(pow (of_int 2) (of_int length_in_bits) - one)
    in
    Quickcheck.Generator.map
      Bignum_bigint.(gen_incl zero m)
      ~f:(fun x -> Bigint.(to_field (of_bignum_bigint x)))

  type var =
    { digest: Random_oracle.Checked.Digest.t
    ; mutable bits: Boolean.var Bitstring.Lsb_first.t option }

  let var_of_t t =
    let n = Bigint.of_field t in
    { digest= Field.Var.constant t
    ; bits=
        Some
          (Bitstring.Lsb_first.of_list
             (List.init M.length_in_bits ~f:(fun i ->
                  Boolean.var_of_value (Bigint.test_bit n i) ))) }

  open Let_syntax

  let var_to_hash_packed {digest; _} = digest

  (* TODO: Audit this usage of choose_preimage *)
  let unpack =
    if Int.( = ) length_in_bits Field.size_in_bits then fun x ->
      Field.Checked.choose_preimage_var x ~length:length_in_bits
      >>| fun x -> (x :> Boolean.var list)
    else Field.Checked.unpack ~length:length_in_bits

  let%snarkydef var_to_bits t =
    match t.bits with
    | Some bits ->
        return (bits :> Boolean.var list)
    | None ->
        let%map bits = unpack t.digest in
        t.bits <- Some (Bitstring.Lsb_first.of_list bits) ;
        bits

  let var_to_input (t : var) = Random_oracle.Input.field t.digest

  (* TODO : use Random oracle.Digest to satisfy Bits_intf.S, move out of
     consensus_mechanism guard
  *)
  module Bs =
    Snark_bits.Bits.Make_field
      (Snark_params.Tick.Field)
      (Snark_params.Tick.Bigint)

  include (Bs : module type of Bs with type t := t)

  let assert_equal x y = Field.Checked.Assert.equal x.digest y.digest

  let equal_var x y = Field.Checked.equal x.digest y.digest

  let typ : (var, t) Typ.t =
    Typ.transport_var Typ.field
      ~there:(fun {digest; bits= _} -> digest)
      ~back:(fun digest -> {digest; bits= None})

  [%%endif]
end

module T0 = struct
  [%%versioned_asserted
  module Stable = struct
    module V1 = struct
      type t = Field.t
      [@@deriving sexp, compare, hash, version {asserted}, bin_io]

      let to_latest = Fn.id
    end

    module Tests = struct end
  end]

  module Tests = struct
    (* these test the stability of the serialization derived from the
       string representation of Field.t, not the direct serialization of
       Field.t
    *)

    let field =
      Quickcheck.random_value ~seed:(`Deterministic "Data_hash.T0 tests")
        Field.gen

    [%%if
    curve_size = 255]

    let%test "Binable from stringable V1" =
      let known_good_digest = "8fffa8b873e2f0600ad8327fa5423859" in
      Ppx_version_runtime.Serialization.check_serialization
        (module Stable.V1)
        field known_good_digest

    [%%else]

    let%test "Binable from stringable V1" =
      failwith "No test for this curve size"

    [%%endif]
  end
end

module Make_full_size (B58_data : Data_hash_intf.Data_hash_descriptor) = struct
  module Basic = Make_basic (struct
    let length_in_bits = Field.size_in_bits
  end)

  include Basic

  module Base58_check = Codable.Make_base58_check (struct
    include T0.Stable.Latest

    (* the serialization here is only used for the hash impl which is only
       used for hashtbl, it's ok to disagree with the "real" serialization *)
    include Hashable.Make_binable (T0.Stable.Latest)
    include B58_data
  end)

  [%%define_locally
  Base58_check.(to_base58_check, of_base58_check, of_base58_check_exn)]

  [%%define_locally
  Base58_check.String_ops.(to_string, of_string)]

  [%%define_locally
  Base58_check.(to_yojson, of_yojson)]

  module T = struct
    type t = Field.t [@@deriving sexp, compare, hash]
  end

  include Comparable.Make (T)
  include Hashable.Make (T)

  let of_hash = Fn.id

  let dhall_type = Ppx_dhall_type.Dhall_type.Text

  [%%ifdef
  consensus_mechanism]

  let var_of_hash_packed digest = {digest; bits= None}

  let if_ cond ~then_ ~else_ =
    let%map digest =
      Field.Checked.if_ cond ~then_:then_.digest ~else_:else_.digest
    in
    {digest; bits= None}

  [%%endif]
end
