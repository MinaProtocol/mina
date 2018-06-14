open Core
open Util
open Snark_params.Tick

module type Basic = sig
  type t = private Pedersen.Digest.t [@@deriving sexp, eq]

  val bit_length : int

  val ( = ) : t -> t -> bool

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq]

      include Hashable_binable with type t := t
    end
  end

  type var

  val var_of_t : t -> var

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val var_of_hash_unpacked : Pedersen.Digest.Unpacked.var -> var

  val var_to_hash_packed : var -> Pedersen.Digest.Packed.var

  val var_to_bits : var -> (Boolean.var list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  val equal_var : var -> var -> (Boolean.var, _) Checked.t

  include Bits_intf.S with type t := t
end

module type Full_size = sig
  include Basic

  val var_of_hash_packed : Pedersen.Digest.Packed.var -> var

  val of_hash : Pedersen.Digest.t -> t
end

module type Small = sig
  include Basic

  val var_of_hash_packed : Pedersen.Digest.Packed.var -> (var, _) Checked.t

  val of_hash : Pedersen.Digest.t -> t Or_error.t
end

module Make_basic (M : sig
  val bit_length : int

  val unpack :
       Pedersen.Digest.Packed.var
    -> (Boolean.var Bitstring.Lsb_first.t, _) Checked.t
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

  let bit_length = M.bit_length

  let ( = ) = equal

  type var =
    { digest: Pedersen.Digest.Packed.var
    ; mutable bits: Boolean.var Bitstring.Lsb_first.t option }

  let var_of_t =
    let max =
      if M.bit_length < Field.size_in_bits then
        Bignum_bigint.(two_to_the bit_length - one)
      else Field.size
    in
    fun t ->
      let n = Bigint.of_field t in
      assert (Bignum_bigint.( <= ) (Bigint.to_bignum_bigint n) max) ;
      { digest= Cvar.constant t
      ; bits=
          Some
            (Bitstring.Lsb_first.of_list
               (List.init M.bit_length ~f:(fun i ->
                    Boolean.var_of_value (Bigint.test_bit n i) ))) }

  open Let_syntax

  let if_ b ~then_ ~else_ =
    let%map digest = Checked.if_ b ~then_:then_.digest ~else_:else_.digest in
    {digest; bits= None}

  let var_of_hash_unpacked unpacked =
    { digest= Pedersen.Digest.project_var unpacked
    ; bits=
        Some
          (Bitstring.Lsb_first.of_list
             (Pedersen.Digest.Unpacked.var_to_bits unpacked)) }

  let var_to_hash_packed {digest; _} = digest

  (*
  (* TODO: Audit this usage of choose_preimage *)
  let unpack =
    if Int.(=) bit_length Field.size_in_bits
    then
      (fun x -> Pedersen.Digest.choose_preimage_var x
        >>| Pedersen.Digest.Unpacked.var_to_bits)
    else Checked.unpack ~length:bit_length

*)
  let var_to_bits t =
    with_label __LOC__
      ( match t.bits with
      | Some bits -> return (bits :> Boolean.var list)
      | None ->
          let%map bits = M.unpack t.digest in
          t.bits <- Some bits ;
          (bits :> Boolean.var list) )

  include Pedersen.Digest.Bits

  let assert_equal x y = assert_equal x.digest y.digest

  let equal_var x y = Checked.equal x.digest y.digest

  let typ : (var, t) Typ.t =
    let store (t: t) =
      let open Typ.Store.Let_syntax in
      let n = Bigint.of_field t in
      let rec go i acc =
        if i < 0 then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.store (Bigint.test_bit n i) in
          go (i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      {bits= Some bits; digest= Checked.project (bits :> Boolean.var list)}
    in
    let read (t: var) = Field.typ.read t.digest in
    let alloc =
      let open Typ.Alloc.Let_syntax in
      let rec go i acc =
        if i < 0 then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.alloc in
          go (i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      {bits= Some bits; digest= Checked.project (bits :> Boolean.var list)}
    in
    let check {bits; _} =
      Checked.List.iter
        (Option.value_exn bits :> Boolean.var list)
        ~f:Boolean.typ.check
    in
    {store; read; alloc; check}
end

module Make_full_size_loose_unpacking () = struct
  include Make_basic (struct
    let bit_length = Field.size_in_bits

    let unpack x =
      let open Let_syntax in
      Pedersen.Digest.choose_preimage_var x
      >>| Pedersen.Digest.Unpacked.var_to_bits >>| Bitstring.Lsb_first.of_list
  end)

  let var_of_hash_packed digest = {digest; bits= None}

  let of_hash = Fn.id
end

module Make_full_size_strict_unpacking () = struct
  include Make_basic (struct
    let bit_length = Field.size_in_bits

    let unpack = Util.unpack_field_var
  end)

  let var_of_hash_packed digest = {digest; bits= None}

  let of_hash = Fn.id
end

module Make_small (M : sig
  val bit_length : int
end) =
struct
  let () = assert (M.bit_length < Field.size_in_bits)

  let unpack x =
    let open Let_syntax in
    Checked.unpack ~length:M.bit_length x >>| Bitstring.Lsb_first.of_list

  include Make_basic (struct
    include M

    let unpack = unpack
  end)

  open Let_syntax

  let var_of_hash_packed digest =
    let%map bits = unpack digest in
    {digest; bits= Some bits}

  let max = Bignum_bigint.(two_to_the bit_length - one)

  let of_hash x =
    if Bignum_bigint.( <= ) Bigint.(to_bignum_bigint (of_field x)) max then
      Ok x
    else
      Or_error.errorf
        !"Data_hash.of_hash: %{sexp:Pedersen.Digest.t} > \
          %{sexp:Bignum_bigint.t}"
        x max
end
