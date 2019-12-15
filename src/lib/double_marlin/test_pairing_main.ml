open Core_kernel

module Inputs : Intf.Pairing_main_inputs.S = struct
  module Impl = Snarky.Snark.Run.Make (Snarky.Libsnark.Mnt4.Default) (Unit)

  module Fq_constant = struct
    type t = unit

    let size_in_bits = 382
  end

  open Impl

  module App_state = struct
    type t = unit

    module Constant = Unit

    let to_field_elements _ = [||]

    let typ = Typ.unit

    let check_update _ _ = ()
  end

  module Poseidon_inputs = struct
    module Field = struct
      open Impl

      (* The linear combinations involved in computing Poseidon do not involve very many
   variables, but if they are represented as arithmetic expressions (that is, "Cvars"
   which is what Field.t is under the hood) the expressions grow exponentially in
   in the number of rounds. Thus, we compute with Field elements represented by
   a "reduced" linear combination. That is, a coefficient for each variable and an
   constant term.
*)
      type t = Impl.field Int.Map.t * Impl.field

      let to_cvar ((m, c) : t) : Field.t =
        Map.fold m ~init:(Field.constant c) ~f:(fun ~key ~data acc ->
            let x =
              let v = Snarky.Cvar.Var key in
              if Field.Constant.equal data Field.Constant.one then v
              else Scale (data, v)
            in
            match acc with
            | Constant c when Field.Constant.equal Field.Constant.zero c ->
                x
            | _ ->
                Add (x, acc) )

      let constant c = (Int.Map.empty, c)

      let of_cvar (x : Field.t) =
        match x with
        | Constant c ->
            constant c
        | Var v ->
            (Int.Map.singleton v Field.Constant.one, Field.Constant.zero)
        | x ->
            let c, ts = Field.to_constant_and_terms x in
            ( Int.Map.of_alist_reduce
                (List.map ts ~f:(fun (f, v) -> (Impl.Var.index v, f)))
                ~f:Field.Constant.add
            , Option.value ~default:Field.Constant.zero c )

      let ( + ) (t1, c1) (t2, c2) =
        ( Map.merge t1 t2 ~f:(fun ~key:_ t ->
              match t with
              | `Left x ->
                  Some x
              | `Right y ->
                  Some y
              | `Both (x, y) ->
                  Some Field.Constant.(x + y) )
        , Field.Constant.add c1 c2 )

      let ( * ) (t1, c1) (t2, c2) =
        assert (Int.Map.is_empty t1) ;
        (Map.map t2 ~f:(Field.Constant.mul c1), Field.Constant.mul c1 c2)

      let zero : t = constant Field.Constant.zero
    end

    let rounds_full = 8

    let rounds_partial = 55

    let to_the_alpha x = Impl.Field.(square (square x) * x)

    let to_the_alpha x = Field.of_cvar (to_the_alpha (Field.to_cvar x))

    module Operations = Sponge.Make_operations (Field)
  end

  module S = Sponge.Make_sponge (Sponge.Poseidon (Poseidon_inputs))

  let sponge_params =
    Sponge.Params.(
      map bn128 ~f:Impl.Field.(Fn.compose constant Constant.of_string))

  module Sponge = struct
    module S = struct
      type t = S.t

      let create ?init params =
        S.create
          ?init:
            (Option.map init
               ~f:(Sponge.State.map ~f:Poseidon_inputs.Field.of_cvar))
          (Sponge.Params.map params ~f:Poseidon_inputs.Field.of_cvar)

      let absorb t input =
        ksprintf Impl.with_label "absorb: %s" __LOC__ (fun () ->
            S.absorb t (Poseidon_inputs.Field.of_cvar input) )

      let squeeze t =
        ksprintf Impl.with_label "squeeze: %s" __LOC__ (fun () ->
            Poseidon_inputs.Field.to_cvar (S.squeeze t) )
    end

    include Sponge.Make_bit_sponge (struct
                type t = Impl.Boolean.var
              end)
              (struct
                include Impl.Field

                let to_bits t =
                  Bitstring_lib.Bitstring.Lsb_first.to_list
                    (Impl.Field.unpack_full t)
              end)
              (S)

    let absorb t input =
      match input with
      | `Field x ->
          absorb t x
      | `Bits bs ->
          absorb t (Field.pack bs)
  end

  module G = struct
    module Inputs = struct
      module Impl = Impl

      module F = struct
        include struct
          open Impl.Field

          type nonrec t = t

          let ( * ), ( + ), ( - ), inv_exn, square, scale, if_, typ, constant =
            (( * ), ( + ), ( - ), inv, square, scale, if_, typ, constant)

          let negate x = scale x Constant.(negate one)
        end

        module Constant = struct
          open Impl.Field.Constant

          type nonrec t = t

          let ( * ), ( + ), ( - ), inv_exn, square, negate =
            (( * ), ( + ), ( - ), inv, square, negate)
        end

        let assert_square x y = Impl.assert_square x y

        let assert_r1cs x y z = Impl.assert_r1cs x y z
      end

      module Params = struct
        open Impl.Field.Constant

        let a = zero

        let b = of_int 14

        let one =
          (* Fake *)
          (of_int 1, of_int 1)
      end

      module Constant = struct
        type t = F.Constant.t * F.Constant.t

        let to_affine_exn = Fn.id

        let of_affine = Fn.id

        let random () = Params.one
      end
    end

    module Constant = Inputs.Constant
    module T = Snarky_curve.Make_checked (Inputs)

    type t = T.t

    let typ = T.typ

    let ( + ) _ _ = (exists Field.typ, exists Field.typ)

    let scale t bs =
      let constraints_per_bit =
        let x, _y = t in
        if Option.is_some (Field.to_constant x) then 2 else 6
      in
      ksprintf Impl.with_label "scale %s" __LOC__ (fun () ->
          (* Dummy constraints *)
          let x = exists Field.typ in
          let y = exists Field.typ in
          let num_bits = List.length bs in
          for _ = 1 to constraints_per_bit * num_bits do
            Impl.assert_r1cs x y x
          done ;
          (x, y) )

    (*         T.scale t (Bitstring_lib.Bitstring.Lsb_first.of_list bs) *)
    let to_field_elements (x, y) = [x; y]

    let scale_inv = scale

    let scale_by_quadratic_nonresidue t = T.double (T.double t) + t

    let scale_by_quadratic_nonresidue_inv = scale_by_quadratic_nonresidue

    let negate = T.negate

    let one = T.one

    let if_ b ~then_:(tx, ty) ~else_:(ex, ey) =
      (Field.if_ b ~then_:tx ~else_:ex, Field.if_ b ~then_:ty ~else_:ey)
  end

  let domain_k = Domain.Pow_2_roots_of_unity 18

  let domain_h = Domain.Pow_2_roots_of_unity 18

  module Input_domain = struct
    let domain = Domain.Pow_2_roots_of_unity 5

    let lagrange_commitments =
      Array.init (Domain.size domain) ~f:(fun _ -> G.one)
  end

  module Generators = struct
    let g = G.one

    let h = G.one
  end
end

let%test_unit "pairing-main" =
  let module M = Pairing_main.Main (Inputs) in
  let n =
    let open Vector in
    Inputs.Impl.constraint_count (fun () ->
        M.main
          (Inputs.Impl.exists
             (Snarky.Typ.tuple4 (typ M.Fq.typ Nat.N4.n)
                (typ Inputs.Impl.Field.typ Nat.N3.n)
                (typ M.Challenge.typ Nat.N8.n)
                (Snarky.Typ.array ~length:16
                   (Types.Pairing_based.Bulletproof_challenge.typ
                      M.Challenge.typ Inputs.Impl.Boolean.typ)))) )
  in
  Core.printf "%d\n%!" n
