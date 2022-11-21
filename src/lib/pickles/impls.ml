open Pickles_types
open Core_kernel
open Import
open Backend
module Wrap_impl = Snarky_backendless.Snark.Run.Make (Tock)

(** returns [true] if the [i]th bit of [x] is set to 1 *)
let test_bit x i = B.(shift_right x i land one = one)

(* TODO: I think there are other forbidden values as well. *)

(** returns all the values that can fit in [~size_in_bits] bits and that are
 * either congruent with -2^[~size_in_bits] mod [~modulus] 
 * or congruent with -2^[~size_in_bits] - 1 mod [~modulus] 
 *)
let forbidden_shifted_values ~modulus:r ~size_in_bits =
  let two_to_n = B.(pow (of_int 2) (of_int size_in_bits)) in
  (* this function doesn't make sense if the modulus is smaller *)
  assert (B.(r < two_to_n)) ;
  let neg_two_to_n = B.(neg two_to_n) in
  let representatives x =
    let open Sequence in
    (* All values equivalent to x mod r that fit in [size_in_bits]
       many bits. *)
    let fits_in_n_bits x = B.(x < two_to_n) in
    unfold ~init:B.(x % r) ~f:(fun x -> Some (x, B.(x + r)))
    |> take_while ~f:fits_in_n_bits
    |> to_list
  in
  List.concat_map [ neg_two_to_n; B.(neg_two_to_n - one) ] ~f:representatives
  |> List.dedup_and_sort ~compare:B.compare

module Step = struct
  module Impl = Snarky_backendless.Snark.Run.Make (Tick)
  include Impl
  module R1CS_constraint_system = Tick.R1CS_constraint_system
  module Verification_key = Tick.Verification_key
  module Proving_key = Tick.Proving_key

  module Keypair = struct
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    let create = Fields.create

    let generate ~prev_challenges cs =
      let open Tick.Keypair in
      let keypair = create ~prev_challenges cs in
      { pk = pk keypair; vk = vk keypair }
  end

  module Other_field = struct
    (* Tick.Field.t = p < q = Tock.Field.t *)
    let size_in_bits = Tock.Field.size_in_bits

    module Constant = Tock.Field

    type t = (* Low bits, high bit *)
      Field.t * Boolean.var

    let forbidden_shifted_values =
      let size_in_bits = Constant.size_in_bits in
      let other_mod = Wrap_impl.Bigint.to_bignum_bigint Constant.size in
      let values = forbidden_shifted_values ~size_in_bits ~modulus:other_mod in
      let f x =
        let hi = test_bit x (Field.size_in_bits - 1) in
        let lo = B.shift_right x 1 in
        let lo =
          (* IMPORTANT: in practice we should filter such values
             see: https://github.com/MinaProtocol/mina/pull/9324/commits/82b14cd7f11fb938ab6d88aac19516bd7ea05e94
             but the circuit needs to remain the same, which is to use 0 when a value is larger than the modulus here (tested by the unit test below)
          *)
          let modulus = Impl.Field.size in
          if B.compare modulus lo <= 0 then Tick.Field.zero
          else Impl.Bigint.(to_field (of_bignum_bigint lo))
        in
        (lo, hi)
      in
      values |> List.map ~f

    let%test_unit "preserve circuit behavior for Step" =
      let expected_list =
        [ ("45560315531506369815346746415080538112", false)
        ; ("45560315531506369815346746415080538113", false)
        ; ( "14474011154664524427946373126085988481727088556502330059655218120611762012161"
          , true )
        ; ( "14474011154664524427946373126085988481727088556502330059655218120611762012161"
          , true )
        ]
      in
      let str_list =
        List.map forbidden_shifted_values ~f:(fun (a, b) ->
            (Tick.Field.to_string a, b) )
      in
      assert ([%equal: (string * bool) list] str_list expected_list)

    let typ_unchecked : (t, Constant.t) Typ.t =
      Typ.transport
        (Typ.tuple2 Field.typ Boolean.typ)
        ~there:(fun x ->
          match Tock.Field.to_bits x with
          | [] ->
              assert false
          | low :: high ->
              (Field.Constant.project high, low) )
        ~back:(fun (high, low) ->
          let high = Field.Constant.unpack high in
          Tock.Field.of_bits (low :: high) )

    let check t =
      let open Internal_Basic in
      let open Let_syntax in
      let equal (x1, b1) (x2, b2) =
        let%bind x_eq = Field.Checked.equal x1 (Field.Var.constant x2) in
        let b_eq = match b2 with true -> b1 | false -> Boolean.not b1 in
        Boolean.( && ) x_eq b_eq
      in
      let (Typ typ_unchecked) = typ_unchecked in
      make_checked_ast
      @@ let%bind () = run_checked_ast @@ typ_unchecked.check t in
         Checked.List.map forbidden_shifted_values ~f:(equal t)
         >>= Boolean.any >>| Boolean.not >>= Boolean.Assert.is_true

    let typ : _ Snarky_backendless.Typ.t =
      let (Typ typ_unchecked) = typ_unchecked in
      Typ { typ_unchecked with check }

    let to_bits (x, b) = Field.unpack x ~length:(Field.size_in_bits - 1) @ [ b ]
  end

  module Digest = Digest.Make (Impl)
  module Challenge = Challenge.Make (Impl)

  let input ~proofs_verified ~wrap_rounds ~uses_lookup =
    let open Types.Step.Statement in
    let lookup :
        ( Challenge.Constant.t
        , Impl.Field.t
        , Other_field.Constant.t Pickles_types.Shifted_value.Type2.t
        , Other_field.t Pickles_types.Shifted_value.Type2.t )
        Types.Wrap.Lookup_parameters.t =
      { use = uses_lookup
      ; zero =
          { value =
              { challenge = Limb_vector.Challenge.Constant.zero
              ; scalar = Shifted_value Other_field.Constant.zero
              }
          ; var =
              { challenge = Field.zero
              ; scalar = Shifted_value (Field.zero, Boolean.false_)
              }
          }
      }
    in
    let spec = spec (module Impl) proofs_verified wrap_rounds lookup in
    let (T (typ, f, f_inv)) =
      Spec.packed_typ
        (module Impl)
        (T
           ( Shifted_value.Type2.typ Other_field.typ_unchecked
           , (fun (Shifted_value.Type2.Shifted_value x as t) ->
               Impl.run_checked_ast (Other_field.check x) ;
               t )
           , Fn.id ) )
        spec
    in
    let typ =
      Typ.transport typ
        ~there:(to_data ~option_map:Option.map)
        ~back:(of_data ~option_map:Option.map)
    in
    Spec.ETyp.T
      ( typ
      , (fun x -> of_data ~option_map:Plonk_types.Opt.map (f x))
      , fun x -> f_inv (to_data ~option_map:Plonk_types.Opt.map x) )
end

module Wrap = struct
  module Impl = Wrap_impl
  include Impl
  module Challenge = Challenge.Make (Impl)
  module Digest = Digest.Make (Impl)
  module Wrap_field = Tock.Field
  module Step_field = Tick.Field
  module R1CS_constraint_system = Tock.R1CS_constraint_system
  module Verification_key = Tock.Verification_key
  module Proving_key = Tock.Proving_key

  module Keypair = struct
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    let create = Fields.create

    let generate ~prev_challenges cs =
      let open Tock.Keypair in
      let keypair = create ~prev_challenges cs in
      { pk = pk keypair; vk = vk keypair }
  end

  module Other_field = struct
    module Constant = Tick.Field
    open Impl

    type t = Field.t

    let forbidden_shifted_values =
      let other_mod = Step.Impl.Bigint.to_bignum_bigint Constant.size in
      let size_in_bits = Constant.size_in_bits in
      let values = forbidden_shifted_values ~size_in_bits ~modulus:other_mod in
      let f x =
        let modulus = Impl.Field.size in
        (* IMPORTANT: in practice we should filter such values
           see: https://github.com/MinaProtocol/mina/pull/9324/commits/82b14cd7f11fb938ab6d88aac19516bd7ea05e94
           but the circuit needs to remain the same, which is to use 0 when a value is larger than the modulus here (tested by the unit test below)
        *)
        if B.compare modulus x <= 0 then Wrap_field.zero
        else Impl.Bigint.(to_field (of_bignum_bigint x))
      in
      values |> List.map ~f

    let%test_unit "preserve circuit behavior for Wrap" =
      let expected_list =
        [ "91120631062839412180561524743370440705"
        ; "91120631062839412180561524743370440706"
        ; "0"
        ; "0"
        ]
      in
      let str_list =
        List.map forbidden_shifted_values ~f:Wrap_field.to_string
      in
      assert ([%equal: string list] str_list expected_list)

    let typ_unchecked, check =
      (* Tick -> Tock *)
      let (Typ t0 as typ_unchecked) =
        Typ.transport Field.typ
          ~there:(Fn.compose Tock.Field.of_bits Tick.Field.to_bits)
          ~back:(Fn.compose Tick.Field.of_bits Tock.Field.to_bits)
      in
      let check t =
        let open Internal_Basic in
        let open Let_syntax in
        let equal x1 x2 = Field.Checked.equal x1 (Field.Var.constant x2) in
        make_checked_ast
        @@ let%bind () = run_checked_ast @@ t0.check t in
           Checked.List.map forbidden_shifted_values ~f:(equal t)
           >>= Boolean.any >>| Boolean.not >>= Boolean.Assert.is_true
      in
      (typ_unchecked, check)

    let typ : _ Snarky_backendless.Typ.t =
      let (Typ typ_unchecked) = typ_unchecked in
      Typ { typ_unchecked with check }

    let to_bits x = Field.unpack x ~length:Field.size_in_bits
  end

  let input () =
    let lookup =
      { Types.Wrap.Lookup_parameters.use = No
      ; zero =
          { value =
              { challenge = Limb_vector.Challenge.Constant.zero
              ; scalar =
                  Shifted_value.Type1.Shifted_value Other_field.Constant.zero
              }
          ; var =
              { challenge = Impl.Field.zero
              ; scalar = Shifted_value.Type1.Shifted_value Impl.Field.zero
              }
          }
      }
    in
    let fp : (Impl.Field.t, Other_field.Constant.t) Typ.t =
      Other_field.typ_unchecked
    in
    let open Types.Wrap.Statement in
    let (T (typ, f, f_inv)) =
      Spec.packed_typ
        (module Impl)
        (T
           ( Shifted_value.Type1.typ fp
           , (fun (Shifted_value x as t) ->
               Impl.run_checked_ast (Other_field.check x) ;
               t )
           , Fn.id ) )
        (In_circuit.spec (module Impl) lookup)
    in
    let typ =
      Typ.transport typ
        ~there:(In_circuit.to_data ~option_map:Option.map)
        ~back:(In_circuit.of_data ~option_map:Option.map)
    in
    Spec.ETyp.T
      ( typ
      , (fun x -> In_circuit.of_data ~option_map:Plonk_types.Opt.map (f x))
      , fun x -> f_inv (In_circuit.to_data ~option_map:Plonk_types.Opt.map x) )
end
