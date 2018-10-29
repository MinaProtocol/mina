(* TODO: rename length_in_bits -> bit_length *)

open Core
open Util
open Snark_params.Tick
open Snark_bits
open Bitstring_lib
open Tuple_lib
open Fold_lib

module type Basic = sig
  type t = private Pedersen.Digest.t
  [@@deriving bin_io, sexp, eq, compare, hash]

  val gen : t Quickcheck.Generator.t

  val to_bytes : t -> string

  val length_in_triples : int

  val ( = ) : t -> t -> bool

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq, hash]

      include Hashable_binable with type t := t
    end
  end

  type var

  val var_of_hash_unpacked : Pedersen.Checked.Digest.Unpacked.var -> var

  val var_to_hash_packed : var -> Pedersen.Checked.Digest.var

  val var_to_triples : var -> (Boolean.var Triple.t list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  val equal_var : var -> var -> (Boolean.var, _) Checked.t

  val var_of_t : t -> var

  include Bits_intf.S with type t := t

  include Hashable.S with type t := t

  val fold : t -> bool Triple.t Fold.t
end

module type Full_size = sig
  include Basic

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val var_of_hash_packed : Pedersen.Checked.Digest.var -> var

  val of_hash : Pedersen.Digest.t -> t
end

module type Small = sig
  include Basic

  val var_of_hash_packed : Pedersen.Checked.Digest.var -> (var, _) Checked.t

  val of_hash : Pedersen.Digest.t -> t Or_error.t
end

module Make_basic (M : sig
  val length_in_bits : int
end) =
struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Pedersen.Digest.t [@@deriving bin_io, sexp, eq, compare, hash]
      end

      include T
      include Hashable.Make_binable (T)
    end
  end

  include Stable.V1

  let to_bytes t =
    Fold_lib.Fold.bool_t_to_string (Fold.of_list (Field.unpack t))

  let length_in_bits = M.length_in_bits

  let () = assert (length_in_bits <= Field.size_in_bits)

  let length_in_triples = bit_length_to_triple_length length_in_bits

  let gen : t Quickcheck.Generator.t =
    let m =
      if length_in_bits = Field.size_in_bits then
        Bignum_bigint.(Field.size - one)
      else Bignum_bigint.(pow (of_int 2) (of_int length_in_bits) - one)
    in
    Quickcheck.Generator.map
      Bignum_bigint.(gen_incl zero m)
      ~f:(fun x -> Bigint.(to_field (of_bignum_bigint x)))

  let ( = ) = equal

  type var =
    { digest: Pedersen.Checked.Digest.var
    ; mutable bits: Boolean.var Bitstring.Lsb_first.t option }

  let var_of_t t =
    let n = Bigint.of_field t in
    { digest= Field.Checked.constant t
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

  let var_to_bits t =
    with_label __LOC__
      ( match t.bits with
      | Some bits -> return (bits :> Boolean.var list)
      | None ->
          let%map bits = unpack t.digest in
          t.bits <- Some (Bitstring.Lsb_first.of_list bits) ;
          bits )

  let var_to_triples t =
    var_to_bits t >>| Bitstring.pad_to_triple_list ~default:Boolean.false_

  include Pedersen.Digest.Bits

  let fold = Pedersen.Digest.fold

  let assert_equal x y = Field.Checked.Assert.equal x.digest y.digest

  let equal_var x y = Field.Checked.equal x.digest y.digest

  let typ : (var, t) Typ.t =
    let store (t : t) =
      let open Typ.Store.Let_syntax in
      let n = Bigint.of_field t in
      let rec go i acc =
        if i < 0 then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.store (Bigint.test_bit n i) in
          go (i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      { bits= Some bits
      ; digest= Field.Checked.project (bits :> Boolean.var list) }
    in
    let read (t : var) = Field.typ.read t.digest in
    let alloc =
      let open Typ.Alloc.Let_syntax in
      let rec go i acc =
        if i < 0 then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.alloc in
          go (i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      { bits= Some bits
      ; digest= Field.Checked.project (bits :> Boolean.var list) }
    in
    let check {bits; _} =
      Checked.List.iter
        (Option.value_exn bits :> Boolean.var list)
        ~f:Boolean.typ.check
    in
    {store; read; alloc; check}
end

module Make_full_size () = struct
  include Make_basic (struct
    let length_in_bits = Field.size_in_bits
  end)

  let var_of_hash_packed digest = {digest; bits= None}

  let of_hash = Fn.id

  let if_ cond ~then_ ~else_ =
    let open Let_syntax in
    let%map digest =
      Field.Checked.if_ cond ~then_:then_.digest ~else_:else_.digest
    in
    {digest; bits= None}
end

module Make_small (M : sig
  val length_in_bits : int
end) =
struct
  let () = assert (M.length_in_bits < Field.size_in_bits)

  include Make_basic (M)
  open Let_syntax

  let var_of_hash_packed digest =
    let%map bits = unpack digest in
    {digest; bits= Some (Bitstring.Lsb_first.of_list bits)}

  let max = Bignum_bigint.(two_to_the length_in_bits - one)

  let of_hash x =
    if Bignum_bigint.( <= ) Bigint.(to_bignum_bigint (of_field x)) max then
      Ok x
    else
      Or_error.errorf
        !"Data_hash.of_hash: %{sexp:Pedersen.Digest.t} > \
          %{sexp:Bignum_bigint.t}"
        x max
end
