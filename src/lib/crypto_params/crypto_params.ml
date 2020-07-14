open Core
include Curve_choice

module Tock_backend = struct
  module Full = Cycle.Mnt6

  module Bowe_gabizon = struct
    let bg_salt =
      lazy (Random_oracle.salt (Hash_prefixes.bowe_gabizon_hash :> string))

    let bg_params () = Lazy.force Group_map_params.params

    include Snarky.Libsnark.Make_bowe_gabizon
              (Full)
              (Bowe_gabizon_hash.Make (struct
                module Field = Tick0.Field

                module Fqe = struct
                  type t = Full.Fqe.t

                  let to_list x =
                    let v = Full.Fqe.to_vector x in
                    List.init (Field.Vector.length v) ~f:(Field.Vector.get v)
                end

                module G1 = Full.G1
                module G2 = Full.G2

                let group_map x =
                  Group_map.to_group (module Field) ~params:(bg_params ()) x

                let hash xs = Random_oracle.hash ~init:(Lazy.force bg_salt) xs
              end))

    module Field = Full.Field
    module Bigint = Full.Bigint
    module Var = Full.Var

    module R1CS_constraint_system = struct
      include Full.R1CS_constraint_system

      let finalize = swap_AB_if_beneficial
    end

    let field_size = Full.field_size
  end

  include Bowe_gabizon
  module Inner_curve = Cycle.Mnt4.G1
  module Inner_twisted_curve = Cycle.Mnt4.G2
end

module Tock0 = Snarky.Snark.Make (Tock_backend)

module Wrap_input = struct
  (*
   The input to a Tick snark is always a Tick.field element which is a pedersen hash.

   If Tock.field is bigger,
   we have the input to wrapping SNARKs be a single Tock.field element
   (since it just needs to faithfully represent 1 Tick element)

   If Tock.field is smaller,
   we have the input to wrapping SNARKs be two field elements
   one of which will be (n - 1) bits and one of which will be 1 bit.
   This should basically cost the same as the above.
*)

  open Bitstring_lib

  module type S = sig
    open Tock0

    type t

    type var

    val of_tick_field : Tick0.Field.t -> t

    val typ : (var, t) Typ.t

    module Checked : sig
      val tick_field_to_scalars :
           Tick0.Field.Var.t
        -> (Tick0.Boolean.var Bitstring.Lsb_first.t list, _) Tick0.Checked.t

      val to_scalar : var -> (Boolean.var Bitstring.Lsb_first.t, _) Checked.t
    end
  end

  module Tock_field_larger : S = struct
    open Tock0

    type var = Field.Var.t

    type t = Field.t

    let typ = Field.typ

    let of_tick_field (x : Tick0.Field.t) : t =
      Tock0.Field.project (Tick0.Field.unpack x)

    module Checked = struct
      let tick_field_to_scalars x =
        let open Tick0 in
        let open Let_syntax in
        Field.Checked.choose_preimage_var x ~length:Field.size_in_bits
        >>| fun x -> [Bitstring.Lsb_first.of_list x]

      let to_scalar x =
        let open Let_syntax in
        Field.Checked.choose_preimage_var ~length:Tick0.Field.size_in_bits x
        >>| Bitstring.Lsb_first.of_list
    end
  end

  module Tock_field_smaller : S = struct
    open Tock0

    type var = {low_bits: Field.Var.t; high_bit: Boolean.var}
    [@@deriving hlist]

    type t = Tick0.Field.t

    let spec = Data_spec.[Field.typ; Boolean.typ]

    (* This is duplicated. Where to put utility functions? *)
    let split_last_exn =
      let rec go acc x xs =
        match xs with
        | [] ->
            (List.rev acc, x)
        | x' :: xs ->
            go (x :: acc) x' xs
      in
      function
      | [] -> failwith "split_last: Empty list" | x :: xs -> go [] x xs

    let of_tick_field (x : Tick0.Field.t) : t = x

    let typ : (var, t) Typ.t =
      Typ.of_hlistable spec ~var_to_hlist ~var_of_hlist
        ~value_to_hlist:(fun (x : Tick0.Field.t) ->
          let low_bits, high_bit = split_last_exn (Tick0.Field.unpack x) in
          [Tock0.Field.project low_bits; high_bit] )
        ~value_of_hlist:(fun Snarky.H_list.[low_bits; high_bit] ->
          Tick0.Field.project (Tock0.Field.unpack low_bits @ [high_bit]) )

    module Checked = struct
      let tick_field_to_scalars x =
        let open Tick0 in
        let open Let_syntax in
        Field.Checked.choose_preimage_var ~length:Field.size_in_bits x
        >>| fun x ->
        let low_bits, high_bit = split_last_exn x in
        [ Bitstring.Lsb_first.of_list low_bits
        ; Bitstring.Lsb_first.of_list [high_bit] ]

      let to_scalar {low_bits; high_bit} =
        let%map low_bits =
          Field.Checked.unpack ~length:(Tick0.Field.size_in_bits - 1) low_bits
        in
        Bitstring.Lsb_first.of_list (low_bits @ [high_bit])
    end
  end

  let m =
    if Bigint.(Tock0.Field.size < Tick0.Field.size) then
      (module Tock_field_smaller : S )
    else (module Tock_field_larger : S)

  include (val m)

  let size = Tock0.Data_spec.size [typ]
end
