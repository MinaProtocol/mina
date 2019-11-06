open Core
module Input = Input
module Intf = Intf

module Rounds = struct
  (* These rounds are for alpha=11. We use alpha=13 for Tock, so these are conservative
   as security increases monotonically in alpha. *)
  let rounds_full = 8

  let rounds_partial = 33
end

type alpha = N11 | N13

module Make
    (Run : Snarky.Snark_intf.Run) (Alpha : sig
        val alpha : alpha
    end) (Params : sig
      val mds : Run.Field.Constant.t array array

      val round_constants : Run.Field.Constant.t array array
    end) : Intf.Full(Run.Field.Constant).S with module State := Sponge.State =
struct
  let params : _ Sponge.Params.t =
    let open Params in
    {round_constants; mds}

  let pack_input ~project {Input.field_elements; bitstrings} =
    let packed_bits =
      let xs, final, len_final =
        Array.fold bitstrings ~init:([], [], 0)
          ~f:(fun (acc, curr, n) bitstring ->
            let k = List.length bitstring in
            let n' = k + n in
            if n' >= Run.Field.size_in_bits then
              (project curr :: acc, bitstring, k)
            else (acc, bitstring @ curr, n') )
      in
      if len_final = 0 then xs else project final :: xs
    in
    Array.append field_elements (Array.of_list_rev packed_bits)

  module Digest = struct
    open Run.Field.Constant

    type nonrec t = t

    let to_bits ?length x =
      match length with
      | None ->
          unpack x
      | Some length ->
          List.take (unpack x) length
  end

  module Inputs = struct
    include Rounds
    module Field = Run.Field.Constant

    let to_the_11 x =
      let open Field in
      let res = x + zero in
      res *= res ;
      (* x^2 *)
      res *= res ;
      (* x^4 *)
      res *= x ;
      (* x^5 *)
      res *= res ;
      (* x^10 *)
      res *= x ;
      res

    let to_the_13 x =
      let open Field in
      let res = x + zero in
      res *= res ;
      (* x^2 *)
      res *= x ;
      (* x^3 *)
      res *= res ;
      (* x^6 *)
      res *= res ;
      (* x^12 *)
      res *= x ;
      (* x^13 *)
      res

    let to_the_alpha =
      match Alpha.alpha with N11 -> to_the_11 | N13 -> to_the_13

    module Operations = struct
      let apply_matrix rows v =
        Array.map rows ~f:(fun row ->
            let open Field in
            let res = zero + zero in
            Array.iteri row ~f:(fun i r -> res += (r * v.(i))) ;
            res )

      let add_block ~state block =
        Array.iteri block ~f:(fun i b ->
            let open Field in
            state.(i) += b )

      (* TODO: Have an explicit function for making a copy of a field element. *)
      let copy a = Array.map a ~f:(fun x -> Field.(x + zero))
    end
  end

  include Sponge.Make (Sponge.Poseidon (Inputs))

  let update ~state = update ~state params

  let hash ?init = hash ?init params

  module Checked = struct
    module Digest = struct
      open Run.Field

      type nonrec t = t

      let to_bits ?(length = size_in_bits) x =
        List.take (choose_preimage_var ~length:size_in_bits x) length
    end

    module Inputs = struct
      module Field = struct
        module Field = Run.Field.Constant

        (* The linear combinations involved in computing Poseidon do not involve very many
      variables, but if they are represented as arithmetic expressions (that is, "Cvars"
      which is what Field.t is under the hood) the expressions grow exponentially in
      in the number of rounds. Thus, we compute with Field elements represented by
      a "reduced" linear combination. That is, a coefficient for each variable and an
      constant term.
    *)
        type t = Field.t Int.Map.t * Field.t

        let to_cvar ((m, c) : t) : Run.Field.t =
          Map.fold m ~init:(Snarky.Cvar.Constant c) ~f:(fun ~key ~data acc ->
              let x =
                let v = Snarky.Cvar.Var key in
                if Field.equal data Field.one then v else Scale (data, v)
              in
              match acc with
              | Constant c when Field.equal Field.zero c ->
                  x
              | _ ->
                  Add (x, acc) )

        let constant c = (Int.Map.empty, c)

        let of_cvar (x : Run.Field.t) =
          match x with
          | Constant c ->
              constant c
          | Var v ->
              (Int.Map.singleton v Field.one, Field.zero)
          | x ->
              let c, ts = Run.Field.to_constant_and_terms x in
              ( Int.Map.of_alist_reduce
                  (List.map ts ~f:(fun (f, v) -> (Run.Var.index v, f)))
                  ~f:Field.( + )
              , Option.value ~default:Field.zero c )

        let ( + ) (t1, c1) (t2, c2) =
          ( Map.merge t1 t2 ~f:(fun ~key:_ t ->
                match t with
                | `Left x ->
                    Some x
                | `Right y ->
                    Some y
                | `Both (x, y) ->
                    Some Field.(x + y) )
          , Field.( + ) c1 c2 )

        let ( * ) (t1, c1) (t2, c2) =
          assert (Int.Map.is_empty t1) ;
          (Map.map t2 ~f:(Field.( * ) c1), Field.( * ) c1 c2)

        let zero = constant Field.zero
      end

      include Rounds
      module Operations = Sponge.Make_operations (Field)
      open Run.Field

      (* x -> x^11 *)
      let to_the_11 x =
        let zero = square in
        let one a = square a * x in
        let one' = x in
        one' |> zero |> one |> one

      (* x -> x^13 *)
      let to_the_13 x =
        let zero = square in
        let one a = square a * x in
        let one' = x in
        one' |> one |> zero |> one

      let to_the_alpha =
        match Alpha.alpha with N11 -> to_the_11 | N13 -> to_the_13

      let to_the_alpha x = Field.of_cvar (to_the_alpha (Field.to_cvar x))
    end

    include Sponge.Make (Sponge.Poseidon (Inputs))

    let params = Sponge.Params.map ~f:Inputs.Field.constant params

    open Inputs.Field

    let update ~state xs =
      let f = Array.map ~f:of_cvar in
      update params ~state:(f state) (f xs) |> Array.map ~f:to_cvar

    let hash ?init xs =
      O1trace.measure "Random_oracle.hash" (fun () ->
          hash
            ?init:(Option.map init ~f:(Sponge.State.map ~f:constant))
            params (Array.map xs ~f:of_cvar)
          |> to_cvar )

    let pack_input = pack_input ~project:Run.Field.project

    let initial_state = Array.map initial_state ~f:to_cvar

    let digest xs = xs.(0)
  end

  let pack_input = pack_input ~project:Inputs.Field.project

  let prefix_to_field (s : string) =
    let bits_per_character = 8 in
    assert (bits_per_character * String.length s < Inputs.Field.size_in_bits) ;
    Inputs.Field.project Fold_lib.Fold.(to_list (string_bits (s :> string)))

  let salt (s : string) = update ~state:initial_state [|prefix_to_field s|]
end
