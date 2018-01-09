open Core_kernel
open Util
open Snark_params

module Extend (Impl : Camlsnark.Snark_intf.S) = struct
  include Impl

  module Snarkable = struct
    module type S = sig
      type var
      type value
      val spec : (var, value) Var_spec.t
    end

    module Bits = struct
      module type S = sig
        val bit_length : int

        module Packed : sig
          type var
          type value
          val spec : (var, value) Var_spec.t
        end

        module Unpacked : sig
          type var = Boolean.var list
          type value
          val spec : (var, value) Var_spec.t

          module Padded : sig
            type var = private Boolean.var list
            type value
            val spec : (var, value) Var_spec.t
          end
        end

        module Checked : sig
          val pad : Unpacked.var -> Unpacked.Padded.var
          val unpack : Packed.var -> (Unpacked.var, _) Checked.t
        end
      end
    end
  end
end

module Make_types (Impl : Snark_intf.S) = struct
  module Digest = Pedersen.Main.Digest.Snarkable(Impl)
  module Time = Block_time.Snarkable(Impl)
  module Target = Digest
  module Nonce = Nonce.Snarkable(Impl)
  module Strength = Strength.Snarkable(Impl)
  module Block = Block.Snarkable(Impl)(Digest)(Time)(Nonce)(Strength)

  module Scalar = Pedersen.Main.Curve.Scalar(Impl)
end

module Main = struct
  module T = Extend(Snark_params.Main)

  include T
  include Make_types(T)

  module Hash_curve =
    Camlsnark.Curves.Edwards.Extend
      (T)
      (Scalar)
      (Pedersen.Main.Curve)

  module Pedersen = Camlsnark.Pedersen.Make(T)(struct
      include Hash_curve
      let cond_add = Checked.cond_add
    end)

  module Util = Snark_util.Make(T)

  let hash_digest x =
    let open Checked in
    Pedersen.hash x
      ~params:Pedersen_params.t
      ~init:Hash_curve.Checked.identity
    >>| Pedersen.digest

end
module Other = struct
  module T = Extend(Snark_params.Other)
  include T
  include Make_types(T)
end


let () = assert (Main.Field.size_in_bits = Other.Field.size_in_bits)

let step_input () =
  let open Main in
  let open Data_spec in
  [ Digest.Packed.spec (* Self key hash *)
  ; Digest.Packed.spec (* Block header hash *)
  ]

module Wrap = struct
  let step_input_size = Main.Data_spec.size (step_input ())

  open Other

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Other)(Other_curve)(Main_curve)
      (struct let input_size = step_input_size end)

  (* TODO: These numbers are wrong *)
  let step_vk_length = 11324
  let step_vk_size = 38
  let step_vk_spec =
    Var_spec.list ~length:step_vk_size Var_spec.field

  let input_spec =
    Var_spec.list ~length:step_input_size Var_spec.field

  let input () =
    Data_spec.([ step_vk_spec; input_spec ])

  module Prover_state = struct
    type t =
      { vk    : Main_curve.Verification_key.t
      ; proof : Main_curve.Proof.t
      }
  end

  let main verification_key (input : Cvar.t list) =
    let open Let_syntax in
    let%bind v =
      let%bind input =
        List.map ~f:(Checked.unpack ~length:Main_curve.Field.size_in_bits) input
        |> Checked.all
        |> Checked.map ~f:List.concat
      in
      (* TODO: Unpacking here is totally pointless. Edit libsnark
          so we don't have to do this. *)
      let%bind verification_key =
        List.map ~f:(Checked.unpack ~length:Main_curve.Field.size_in_bits) verification_key
        |> Checked.all
        |> Checked.map ~f:List.concat
      in
      Verifier.All_in_one.create ~verification_key ~input
        As_prover.(map get_state ~f:(fun {Prover_state.vk; proof} ->
          { Verifier.All_in_one.verification_key=vk; proof }))
    in
    assert_equal (Verifier.All_in_one.result v :> Cvar.t) (Cvar.constant Field.one)
  ;;
end

module Block0 = Block

module Make_transition_system (M : sig
    open Main

    module State : sig
      type var
      type value
      val spec : (var, value) Var_spec.t

      val is_base_hash : Digest.Packed.var -> (Boolean.var, _) Checked.t
      val hash : var -> (Digest.Packed.var, _) Checked.t
    end

    module Update : sig
      type var
      type value
      val spec : (var, value) Var_spec.t

      val apply
        : var
        -> State.var
        -> (State.var * [ `Success of Boolean.var ], _) Checked.t
    end
  end)
= struct
  open M

  module Prover_state = struct
    type t =
      { self       : bool list
      ; prev_state : State.value
      ; update     : Update.value
      }
    [@@deriving fields]
  end

  open Main
  open Let_syntax

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Main)(Main_curve)(Other_curve)
      (struct let input_size = Other.Data_spec.size (Wrap.input ()) end)

  let input = step_input

  let self_vk_spec =
    Var_spec.list ~length:Wrap.step_vk_length Boolean.spec

  let get spec ~f = store spec As_prover.(map get_state ~f)

  let unhash ~spec ~f ~to_bits h =
    let%bind b = get spec ~f in
    let%bind h' = hash_digest (to_bits b) in
    let%map () = assert_equal h h' in
    b
  ;;

  let main self_hash_packed state_hash =
    let%bind is_base_case = State.is_base_hash state_hash in
    let%bind self =
      unhash self_hash_packed ~f:Prover_state.self
        ~spec:self_vk_spec ~to_bits:Fn.id
    in
    let%bind prev_state = get State.spec ~f:Prover_state.prev_state
    and update          = get Update.spec ~f:Prover_state.update
    in
    let%bind (next_state, `Success success) = Update.apply update prev_state in
    let%bind correct_hash =
      State.hash next_state >>= Checked.equal state_hash
    in
    let%bind inductive_case_passed =
      Boolean.(success && correct_hash)
    in
    Checked.Assert.any
      [ is_base_case
      ; inductive_case_passed
      ]
end

module Step = struct
  open Main
  open Let_syntax

  module State = struct
    let difficulty_window = 10

    type ('time, 'target, 'digest) t =
      (* Someday: To avoid hashing a big list it might be better to make this a blockchain
         (that is verified as things go). *)
      { difficulty_info : ('time * 'target) list
      ; block_hash      : 'digest
      }

(* Someday: It may well be worth using bitcoin's compact nbits for target values since
   targets are quite chunky *)
    type var = (Time.Unpacked.var, Target.Unpacked.var, Digest.Packed.var) t
    type value = (Time.Unpacked.value, Target.Unpacked.value, Digest.Packed.value) t

    let to_hlist { difficulty_info; block_hash } = H_list.([ difficulty_info; block_hash ])
    let of_hlist = H_list.(fun [ difficulty_info; block_hash ] -> { difficulty_info; block_hash })

    let data_spec =
      let open Data_spec in
      [ Var_spec.(list ~length:difficulty_window (tuple2 Time.Unpacked.spec Target.Unpacked.spec))
      ; Digest.Packed.spec
      ]

    let spec : (var, value) Var_spec.t =
      Var_spec.of_hlistable data_spec
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let to_bits { difficulty_info; block_hash } =
      let%map bs = Digest.Checked.unpack block_hash in
      List.concat_map ~f:(fun (x, y) -> x @ y) difficulty_info @ bs

    let hash (t : var) = to_bits t >>= hash_digest 

    let base_hash = Cvar.constant Block0.(hash genesis)
    let is_base_hash h = Checked.equal base_hash h
  end

  module Update = struct
    type var = Block.Packed.var
    type value = Block.Packed.value
    let spec : (var, value) Var_spec.t = Block.Packed.spec

    let all_but_last_exn xs = fst (split_last_exn xs)

    let compute_target _ =
      return (Cvar.constant Field.(negate one))

    let () = assert
      (Target.bit_length = Digest.bit_length)

    let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
      let%map { less } = Util.compare ~length:Target.bit_length target hash in
      less
    ;;

    let apply (block : var) (state : State.var) =
      let%bind target = compute_target state.difficulty_info in
      let%bind block_unpacked = Block.Checked.unpack block in
      let%bind block_hash = hash_digest (Block.Unpacked.to_bits block_unpacked) in
      let%bind meets_target = meets_target target block_hash in
      let%map target_unpacked = Target.Checked.unpack target in
      ( { State.difficulty_info =
            (block_unpacked.header.time, target_unpacked)
            :: all_but_last_exn state.difficulty_info
        ; block_hash
        }
      , `Success meets_target
      )
    ;;
  end
end

module Transition = Make_transition_system(Step)
