open Core_kernel
open Camlsnark

module Main = Snark.Make(Backends.Mnt4)
module Other = Snark.Make(Backends.Mnt6)

let () = assert (Main.Field.size_in_bits = Other.Field.size_in_bits)

module Types (Impl : Snark_intf.S) = struct
  open Impl

  module Bits_types = struct
    type var = Boolean.var list
    type value = Boolean.value list
  end

  module Make_unpacked
      (M : sig val bit_length : int val element_length : int end)
  = struct
    include Bits_types
    let spec : (var, value) Var_spec.t =
      Var_spec.list ~length:M.bit_length Boolean.spec

    module Padded = struct
      include Bits_types

      let spec : (var, value) Var_spec.t =
        Var_spec.list ~length:(M.element_length * Field.size_in_bits)
          Boolean.spec
    end
  end

  module Bits_small(M : sig val bit_length : int end) = struct
    include M

    let () = assert (bit_length < Field.size_in_bits)

    module Packed = struct
      type var = Cvar.t
      type value = Field.t
      let spec = Var_spec.field
    end

    module Unpacked = Make_unpacked(struct
        include M
        let element_length = 1
      end)

    module Checked = struct
      let unpack : Packed.var -> (Unpacked.var, _) Checked.t =
        Checked.unpack ~length:bit_length

      let padding =
        List.init (Field.size_in_bits - bit_length) ~f:(fun _ -> Boolean.false_)

      let pad x = x @ padding
    end
  end

  module Bits0 (M : sig
      val bit_length : int
      val bits_per_element : int
    end) = struct
    include M

    let element_length =
      Float.(to_int (round_up (of_int bit_length / of_int bits_per_element)))

    module Packed = struct
      type var = Cvar.t list
      type value = Field.t list
    end

    module Unpacked = Make_unpacked(struct
        let bit_length = bit_length
        let element_length = element_length
      end)

    module Checked = struct
      let unpack : Packed.var -> (Unpacked.var, _) Checked.t =
        let open Let_syntax in
        let rec go remaining acc = function
          | x :: xs ->
            let to_unpack = min remaining bits_per_element in
            let%bind bs = Checked.unpack x ~length:to_unpack in
            go (remaining - to_unpack) (List.rev_append bs acc) xs
          | [] ->
            assert (remaining = 0);
            return (List.rev acc)
        in
        fun xs -> go bit_length [] xs

      let padding =
        List.init (element_length * Field.size_in_bits - bit_length)
          ~f:(fun _ -> Boolean.false_)

      let pad x = x @ padding
    end

    (* TODO: Would be nice to write this code only once. *)
    let unpack : Packed.value -> Unpacked.value =
      let rec go remaining acc = function
        | x :: xs ->
          let to_unpack = min remaining bits_per_element in
          let bs = List.take (Field.unpack x) to_unpack in
          go (remaining - to_unpack) (List.rev_append bs acc) xs
        | [] ->
          assert (remaining = 0);
          List.rev acc
      in
      fun xs -> go bit_length [] xs

    let padding =
      List.init (element_length * Field.size_in_bits - bit_length)
        ~f:(fun _ -> false)

    let pad x = x @ padding
  end

  module Bits(M : sig val bit_length : int end) =
    Bits0(struct
      include M
      let bits_per_element = Field.size_in_bits - 1
    end)

  module Digest = Bits0(struct
      let bit_length = Field.size_in_bits * 2
      let bits_per_element = Field.size_in_bits
    end)

  module Block = struct
    module Header = struct
    end
  end
end
