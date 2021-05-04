open Core_kernel
open Fold_lib
open Snark_params

module Scalar = struct
  type value = Tick.Inner_curve.Scalar.t

  type var = Tick.Inner_curve.Scalar.var

  let typ : (var, value) Tick.Typ.t = Tick.Inner_curve.Scalar.typ
end

module Group = struct
  open Tick

  type t = Inner_curve.t [@@deriving sexp]

  type value = Inner_curve.t

  type var = Inner_curve.var

  let scale = Inner_curve.scale

  let typ = Inner_curve.typ

  let generator = Inner_curve.one

  let add = Inner_curve.add

  let negate = Inner_curve.negate

  let to_affine_exn = Inner_curve.to_affine_exn

  let of_affine = Inner_curve.of_affine

  module Checked = struct
    include Inner_curve.Checked

    let scale_generator shifted s ~init =
      scale_known shifted Inner_curve.one s ~init
  end
end

module Message = struct
  module Global_slot = Mina_numbers.Global_slot

  type ('global_slot, 'epoch_seed, 'delegator) t =
    {global_slot: 'global_slot; seed: 'epoch_seed; delegator: 'delegator}
  [@@deriving sexp, hlist]

  type value =
    (Global_slot.t, Mina_base.Epoch_seed.t, Mina_base.Account.Index.t) t
  [@@deriving sexp]

  type var =
    ( Global_slot.Checked.t
    , Mina_base.Epoch_seed.var
    , Mina_base.Account.Index.Unpacked.var )
    t

  let to_input
      ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ({global_slot; seed; delegator} : value) =
    { Random_oracle.Input.field_elements= [|(seed :> Tick.field)|]
    ; bitstrings=
        [| Global_slot.Bits.to_bits global_slot
         ; Mina_base.Account.Index.to_bits
             ~ledger_depth:constraint_constants.ledger_depth delegator |] }

  let data_spec
      ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
    let open Tick.Data_spec in
    [ Global_slot.typ
    ; Mina_base.Epoch_seed.typ
    ; Mina_base.Account.Index.Unpacked.typ
        ~ledger_depth:constraint_constants.ledger_depth ]

  let typ ~constraint_constants : (var, value) Tick.Typ.t =
    Tick.Typ.of_hlistable
      (data_spec ~constraint_constants)
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  let hash_to_group ~constraint_constants msg =
    Random_oracle.hash ~init:Mina_base.Hash_prefix.vrf_message
      (Random_oracle.pack_input (to_input ~constraint_constants msg))
    |> Group_map.to_group |> Tick.Inner_curve.of_affine

  module Checked = struct
    open Tick

    let to_input ({global_slot; seed; delegator} : var) =
      let open Tick.Checked.Let_syntax in
      let%map global_slot = Global_slot.Checked.to_bits global_slot in
      let s = Bitstring_lib.Bitstring.Lsb_first.to_list in
      { Random_oracle.Input.field_elements=
          [|Mina_base.Epoch_seed.var_to_hash_packed seed|]
      ; bitstrings= [|s global_slot; delegator|] }

    let hash_to_group msg =
      let%bind input = to_input msg in
      Tick.make_checked (fun () ->
          Random_oracle.Checked.hash ~init:Mina_base.Hash_prefix.vrf_message
            (Random_oracle.Checked.pack_input input)
          |> Group_map.Checked.to_group )
  end

  let gen ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
    let open Quickcheck.Let_syntax in
    let%map global_slot = Global_slot.gen
    and seed = Mina_base.Epoch_seed.gen
    and delegator =
      Mina_base.Account.Index.gen
        ~ledger_depth:constraint_constants.ledger_depth
    in
    {global_slot; seed; delegator}
end

module Output = struct
  module Truncated = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t = string [@@deriving sexp, equal, compare, hash]

        let to_yojson t =
          `String (Base64.encode_exn ~alphabet:Base64.uri_safe_alphabet t)

        let of_yojson = function
          | `String s ->
              Result.map_error
                  (Base64.decode ~alphabet:Base64.uri_safe_alphabet s)
                  ~f:(function `Msg err ->
                  sprintf
                    "Error decoding vrf output in \
                     Vrf.Output.Truncated.Stable.V1.of_yojson: %s"
                    err )
          | _ ->
              Error
                "Vrf.Output.Truncated.Stable.V1.of_yojson: Expected a string"

        let to_latest = Fn.id
      end
    end]

    include Codable.Make_base58_check (struct
      type t = Stable.Latest.t [@@deriving bin_io_unversioned]

      let version_byte = Base58_check.Version_bytes.vrf_truncated_output

      let description = "Vrf Truncated Output"
    end)

    open Tick

    let length_in_bits = Int.min 256 (Field.size_in_bits - 2)

    type var = Boolean.var array

    let typ : (var, t) Typ.t =
      Typ.array ~length:length_in_bits Boolean.typ
      |> Typ.transport
           ~there:(fun s ->
             Array.sub (Blake2.string_to_bits s) ~pos:0 ~len:length_in_bits )
           ~back:Blake2.bits_to_string

    let dummy =
      String.init
        (Base.Int.round ~dir:`Up ~to_multiple_of:8 length_in_bits / 8)
        ~f:(fun _ -> '\000')

    let to_bits t =
      Fold.(to_list (string_bits t)) |> Fn.flip List.take length_in_bits
  end

  open Tick

  let typ = Field.typ

  let gen = Field.gen

  let truncate x =
    Random_oracle.Digest.to_bits ~length:Truncated.length_in_bits x
    |> Array.of_list |> Blake2.bits_to_string

  let hash ~constraint_constants msg g =
    let x, y = Non_zero_curve_point.of_inner_curve_exn g in
    let input =
      Random_oracle.Input.(
        append
          (Message.to_input ~constraint_constants msg)
          (field_elements [|x; y|]))
    in
    let open Random_oracle in
    hash ~init:Hash_prefix_states.vrf_output (pack_input input)

  module Checked = struct
    let truncate x =
      Tick.make_checked (fun () ->
          Random_oracle.Checked.Digest.to_bits ~length:Truncated.length_in_bits
            x
          |> Array.of_list )

    let hash msg (x, y) =
      let%bind msg = Message.Checked.to_input msg in
      let input = Random_oracle.Input.(append msg (field_elements [|x; y|])) in
      make_checked (fun () ->
          let open Random_oracle.Checked in
          hash ~init:Hash_prefix_states.vrf_output (pack_input input) )
  end

  let%test_unit "hash unchecked vs. checked equality" =
    let constraint_constants =
      Genesis_constants.Constraint_constants.for_unit_tests
    in
    let gen_inner_curve_point =
      let open Quickcheck.Generator.Let_syntax in
      let%map compressed = Non_zero_curve_point.gen in
      Non_zero_curve_point.to_inner_curve compressed
    in
    let gen_message_and_curve_point =
      let open Quickcheck.Generator.Let_syntax in
      let%map msg = Message.gen ~constraint_constants
      and g = gen_inner_curve_point in
      (msg, g)
    in
    Quickcheck.test ~trials:10 gen_message_and_curve_point
      ~f:
        (Test_util.test_equal ~equal:Field.equal
           Snark_params.Tick.Typ.(
             Message.typ ~constraint_constants
             * Snark_params.Tick.Inner_curve.typ)
           typ
           (fun (msg, g) -> Checked.hash msg g)
           (fun (msg, g) -> hash ~constraint_constants msg g))
end

module Evaluation_hash = struct
  let hash_for_proof ~constraint_constants message public_key g1 g2 =
    let input =
      let open Random_oracle_input in
      let g_to_input g =
        { field_elements=
            (let f1, f2 = Group.to_affine_exn g in
             [|f1; f2|])
        ; bitstrings= [||] }
      in
      Array.reduce_exn ~f:Random_oracle_input.append
        [| Message.to_input ~constraint_constants message
         ; g_to_input public_key
         ; g_to_input g1
         ; g_to_input g2 |]
    in
    let tick_output =
      Random_oracle.hash ~init:Mina_base.Hash_prefix.vrf_evaluation
        (Random_oracle.pack_input input)
    in
    (* This isn't great cryptographic practice.. *)
    Tick.Field.unpack tick_output |> Tick.Inner_curve.Scalar.project

  module Checked = struct
    let hash_for_proof message public_key g1 g2 =
      let open Tick.Checked.Let_syntax in
      let%bind input =
        let open Random_oracle_input in
        let g_to_input (f1, f2) =
          {field_elements= [|f1; f2|]; bitstrings= [||]}
        in
        let%map message_input = Message.Checked.to_input message in
        Array.reduce_exn ~f:Random_oracle_input.append
          [|message_input; g_to_input public_key; g_to_input g1; g_to_input g2|]
      in
      let%bind tick_output =
        Tick.make_checked (fun () ->
            Random_oracle.Checked.hash
              ~init:Mina_base.Hash_prefix.vrf_evaluation
              (Random_oracle.Checked.pack_input input) )
      in
      (* This isn't great cryptographic practice.. *)
      Tick.Field.Checked.unpack_full tick_output
  end
end

module Output_hash = struct
  type value = Snark_params.Tick.Field.t [@@deriving sexp, compare]

  type t = value

  type var = Random_oracle.Checked.Digest.t

  let hash = Output.hash

  module Checked = struct
    let hash = Output.Checked.hash
  end
end

module Integrated =
  Vrf_lib.Integrated.Make (Tick) (Scalar) (Group) (Message) (Output_hash)

module Standalone (Constraint_constants : sig
  val constraint_constants : Genesis_constants.Constraint_constants.t
end) =
struct
  open Constraint_constants

  include Vrf_lib.Standalone.Make (Tick) (Tick.Inner_curve.Scalar) (Group)
            (struct
              include Message

              let typ = typ ~constraint_constants

              let hash_to_group = hash_to_group ~constraint_constants
            end)
            (struct
              include Output_hash

              let hash = hash ~constraint_constants
            end)
            (struct
              include Evaluation_hash

              let hash_for_proof = hash_for_proof ~constraint_constants
            end)
end

let%test_unit "Standalone and integrates vrfs are consistent" =
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let module Standalone = Standalone (struct
    let constraint_constants = constraint_constants
  end) in
  let inputs =
    let open Quickcheck.Generator.Let_syntax in
    let%bind private_key = Signature_lib.Private_key.gen in
    let%map message = Message.gen ~constraint_constants in
    (private_key, message)
  in
  Quickcheck.test ~seed:(`Deterministic "") inputs
    ~f:(fun (private_key, message) ->
      let integrated_vrf =
        Integrated.eval ~constraint_constants ~private_key message
      in
      let standalone_eval = Standalone.Evaluation.create private_key message in
      let context : Standalone.Context.t =
        { message
        ; public_key=
            Signature_lib.Public_key.of_private_key_exn private_key
            |> Group.of_affine }
      in
      let standalone_vrf =
        Standalone.Evaluation.verified_output standalone_eval context
      in
      [%test_eq: Output_hash.value option] (Some integrated_vrf) standalone_vrf
  )
