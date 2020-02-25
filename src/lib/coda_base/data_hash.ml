(* data_hash.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel
open Bitstring_lib
open Util

[%%if
defined consensus_mechanism]

open Snark_params.Tick

[%%endif]

module type Small = Data_hash_intf.Small

module type Full_size = Data_hash_intf.Full_size

module Make_basic (M : sig
  val length_in_bits : int
end) =
struct
  type t = Pedersen.Digest.t [@@deriving sexp, compare, yojson]

  let to_decimal_string (t : Pedersen.Digest.t) = Field.to_string t

  let to_bytes t =
    Fold_lib.(Fold.bool_t_to_string (Fold.of_list (Field.unpack t)))

  let length_in_bits = M.length_in_bits

  let () = assert (Int.(length_in_bits <= Field.size_in_bits))

  let gen : t Quickcheck.Generator.t =
    let m =
      if Int.(length_in_bits = Field.size_in_bits) then
        Bignum_bigint.(Field.size - one)
      else Bignum_bigint.(pow (of_int 2) (of_int length_in_bits) - one)
    in
    Quickcheck.Generator.map
      Bignum_bigint.(gen_incl zero m)
      ~f:(fun x -> Bigint.(to_field (of_bignum_bigint x)))

  let to_input t = Random_oracle.Input.field t

  [%%if
  defined consensus_mechanism]

  (* SNARK-dependent code *)
  type var =
    { digest: Pedersen.Checked.Digest.var
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

  let var_of_hash_unpacked unpacked =
    { digest= Pedersen.Checked.Digest.Unpacked.project unpacked
    ; bits= Some (Bitstring.Lsb_first.of_list (unpacked :> Boolean.var list))
    }

  let var_to_hash_packed {digest; _} = digest

  (* TODO: Audit this usage of choose_preimage *)
  let unpack =
    if Int.( = ) length_in_bits Field.size_in_bits then fun x ->
      Pedersen.Checked.Digest.choose_preimage x
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

  include Pedersen.Digest.Bits

  let assert_equal x y = Field.Checked.Assert.equal x.digest y.digest

  let equal_var x y = Field.Checked.equal x.digest y.digest

  let typ : (var, t) Typ.t =
    let store (t : t) =
      let open Typ.Store.Let_syntax in
      let n = Bigint.of_field t in
      let rec go i acc =
        if Int.(i < 0) then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.store (Bigint.test_bit n i) in
          go Int.(i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      {bits= Some bits; digest= Field.Var.project (bits :> Boolean.var list)}
    in
    let read (t : var) = Field.typ.read t.digest in
    let alloc =
      let open Typ.Alloc.Let_syntax in
      let rec go i acc =
        if Int.(i < 0) then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.alloc in
          go Int.(i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      {bits= Some bits; digest= Field.Var.project (bits :> Boolean.var list)}
    in
    let check {bits; _} =
      Checked.List.iter
        (Option.value_exn bits :> Boolean.var list)
        ~f:Boolean.typ.check
    in
    {store; read; alloc; check}

  (* end SNARK-dependent *)
  [%%endif]
end

module Make_full_size () = struct
  include Make_basic (struct
    let length_in_bits = Field.size_in_bits
  end)

  (* inside functor of no arguments, versioned types are allowed *)

  [%%versioned
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Pedersen.Digest.Stable.V1.t
        [@@deriving sexp, compare, hash, yojson]
      end

      include T

      let to_latest = Fn.id

      include Comparable.Make (T)
      include Hashable.Make_binable (T)
    end
  end]

  type _unused = unit constraint t = Stable.Latest.t

  include Comparable.Make (Stable.Latest)
  include Hashable.Make (Stable.Latest)

  let of_hash = Fn.id

  [%%if
  defined consensus_mechanism]

  (* SNARK-dependent *)
  let var_of_hash_packed digest = {digest; bits= None}

  let if_ cond ~then_ ~else_ =
    let%map digest =
      Field.Checked.if_ cond ~then_:then_.digest ~else_:else_.digest
    in
    {digest; bits= None}

  [%%endif]
end

module Make_small (M : sig
  val length_in_bits : int
end) =
struct
  let () = assert (M.length_in_bits < Field.size_in_bits)

  include Make_basic (M)

  let var_of_hash_packed digest =
    let%map bits = unpack digest in
    {digest; bits= Some (Bitstring.Lsb_first.of_list bits)}

  let max_size = Bignum_bigint.(two_to_the M.length_in_bits - one)

  let of_hash x =
    if Bignum_bigint.( <= ) Bigint.(to_bignum_bigint (of_field x)) max_size
    then Ok x
    else
      Or_error.errorf
        !"Data_hash.of_hash: %{sexp:Pedersen.Digest.t} > \
          %{sexp:Bignum_bigint.t}"
        x max_size
end
