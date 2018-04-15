open Core
open Snark_params.Tick

module type S = sig
  type t = private Pedersen.Digest.t
  [@@deriving sexp, eq]

  val bit_length : int

  val (=) : t -> t -> bool

  val of_hash : Pedersen.Digest.t -> t

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, eq]
    end
  end

  type var

  val var_of_hash_unpacked : Pedersen.Digest.Unpacked.var -> var
  val var_of_hash_packed : Pedersen.Digest.Packed.var -> var

  val var_to_hash_packed : var -> Pedersen.Digest.Packed.var

  val var_to_bits : var -> (Boolean.var list, _) Checked.t

  val typ : (var, t) Typ.t

  val assert_equal : var -> var -> (unit, _) Checked.t

  include Bits_intf.S with type t := t
end

module Make () = struct
  module Stable = struct
    module V1 = struct
      type t = Pedersen.Digest.t
      [@@deriving bin_io, sexp, eq]
    end
  end

  include Stable.V1

  let bit_length = Field.size_in_bits

  let (=) = equal

  type var =
    { digest       : Pedersen.Digest.Packed.var
    ; mutable bits : Boolean.var Bitstring.Lsb_first.t option
    }

  let var_of_hash_packed digest = { digest; bits = None }
  let var_of_hash_unpacked unpacked =
    { digest = Pedersen.Digest.project_var unpacked
    ; bits = Some (Bitstring.Lsb_first.of_list (Pedersen.Digest.Unpacked.var_to_bits unpacked))
    }

  let var_to_hash_packed { digest; _ } = digest

  let var_to_bits t =
    let open Let_syntax in
    with_label "Data_hash.var_to_bits" begin
      match t.bits with
      | Some bits ->
        return (bits :> Boolean.var list)
      | None ->
        let%map bits =
          Pedersen.Digest.choose_preimage_var t.digest
          >>| Pedersen.Digest.Unpacked.var_to_bits
        in
        t.bits <- Some (Bitstring.Lsb_first.of_list bits);
        bits
    end

  include Pedersen.Digest.Bits

  let assert_equal x y = assert_equal x.digest y.digest

  let typ : (var, t) Typ.t =
    let store (t : t) =
      let open Typ.Store.Let_syntax in
      let n = Bigint.of_field t in
      let rec go i acc =
        if i < 0
        then return (Bitstring.Lsb_first.of_list acc)
        else
          let%bind b = Boolean.typ.store (Bigint.test_bit n i) in
          go (i - 1) (b :: acc)
      in
      let%map bits = go (Field.size_in_bits - 1) [] in
      { bits = Some bits
      ; digest = Checked.project (bits :> Boolean.var list)
      }
    in
    let read (t : var) = Field.typ.read t.digest in
    let bitstring = Typ.list ~length:Field.size_in_bits Boolean.typ in
    let alloc =
      Typ.Alloc.map bitstring.alloc ~f:(fun bits ->
        { digest = Checked.project bits
        ; bits = Some (Bitstring.Lsb_first.of_list bits)
        })
    in
    let check { bits; _ } = bitstring.check (Option.value_exn bits :> Boolean.var list) in
    { store
    ; read
    ; alloc
    ; check
    }

  let of_hash = Fn.id
end

