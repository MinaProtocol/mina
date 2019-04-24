open Core_kernel
include Crypto_params_init
module Pedersen_params = Pedersen_params
module Pedersen_chunk_table = Pedersen_chunk_table

module Tick_pedersen = Chunked_pedersen_lib.Pedersen.Make (struct
  open Tick0
  module Field = Field
  module Bigint = Bigint
  module Curve = Tick_backend.Inner_curve

  let params = Pedersen_params.params

  let chunk_table = Pedersen_chunk_table.chunk_table
end)

module Tock_backend = struct
  module Full = Cycle.Mnt6

  module Bg = struct
    include Snarky.Libsnark.Make_bowe_gabizon
              (Full)
              (struct
                open Full

                let g1_to_bits t =
                  let x, y = G1.to_affine_coordinates t in
                  Tick0.Bigint.(test_bit (of_field y) 0)
                  :: Tick0.Field.unpack x

                let g2_to_bits t =
                  let x, y = G2.to_affine_coordinates t in
                  let open Tick0.Field in
                  let y0 = Vector.get y 0 in
                  assert (not Tick0.Field.(equal y0 zero)) ;
                  Tick0.Bigint.(test_bit (of_field y0) 0)
                  :: List.concat
                       (List.init (Vector.length x) ~f:(fun i ->
                            Tick0.Field.unpack (Vector.get x i) ))

                let salt = lazy (Tick_pedersen.State.salt "TockBGHash")

                let random_oracle =
                  (* TODO: Dedup *)
                  let field_to_bits x =
                    let open Tick0 in
                    let n = Bigint.of_field x in
                    Array.init Field.size_in_bits ~f:(Bigint.test_bit n)
                  in
                  fun x ->
                    Blake2.digest_bits (field_to_bits x)
                    |> Blake2.to_raw_string |> Blake2.string_to_bits
                    |> Array.to_list

                module Group_map =
                  Snarky_group_map.Group_map.Make_unchecked
                    (Tick0.Field)
                    (Tick_backend.Inner_curve.Coefficients)

                let hash ?message ~a ~b ~c ~delta_prime =
                  Tick_pedersen.digest_fold (Lazy.force salt)
                    Fold_lib.Fold.(
                      group3 ~default:false
                        ( of_list (g1_to_bits a)
                        +> of_list (g2_to_bits b)
                        +> of_list (g1_to_bits c)
                        +> of_list (g2_to_bits delta_prime)
                        +> of_array (Option.value ~default:[||] message) ))
                  |> random_oracle |> Tick0.Field.project |> Group_map.to_group
                  |> Tick_backend.Inner_curve.of_affine_coordinates
              end)

    module Field = Full.Field
    module Bigint = Full.Bigint
    module Var = Full.Var
    module R1CS_constraint = Full.R1CS_constraint
    module R1CS_constraint_system = Full.R1CS_constraint_system
    module Linear_combination = Full.Linear_combination

    let field_size = Full.field_size
  end

  include Full.GM
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
      Typ.of_hlistable spec
        ~var_to_hlist:(fun {low_bits; high_bit} -> [low_bits; high_bit])
        ~var_of_hlist:(fun Snarky.H_list.[low_bits; high_bit] ->
          {low_bits; high_bit} )
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
end
