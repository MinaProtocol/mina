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
      module type S = Bits_intf.Snarkable
        with type ('a, 'b) var_spec := ('a, 'b) Var_spec.t
         and type ('a, 'b) checked := ('a, 'b) Checked.t
         and type boolean_var := Boolean.var
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
  [ Digest.Packed.spec (* H(wrap_vk, H(state)) *)
  ]

let step_input_size = Main.Data_spec.size (step_input ())


(*
let step_vk_size = 38

let step_vk_spec =
  Other.(Var_spec.list ~length:step_vk_size Var_spec.field)
   *)

(* TODO: Important that a digest can fit into an Other.Field.t *)
let wrap_input () =
  let open Other in
  let open Data_spec in
  [ Var_spec.field ]

module Make_wrap (M : sig
    val verification_key : Main.Verification_key.t
  end)
= struct
  (* TODO: Important to assert that main field is smaller than other field *)

  let input = wrap_input

  open Other

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Other)(Other_curve)(Main_curve)
      (struct let input_size = step_input_size end)

  module Prover_state = struct
    type t =
      { proof : Main_curve.Proof.t
      }
  end

  let vk_bits =
    Verifier.Verification_key.to_bool_list M.verification_key

  let main (input : Cvar.t) =
    let open Let_syntax in
    let%bind v =
      let%bind input = Checked.unpack ~length:Main_curve.Field.size_in_bits input in
      let verification_key = List.map vk_bits ~f:Boolean.var_of_value in
      Verifier.All_in_one.create ~verification_key ~input
        As_prover.(map get_state ~f:(fun {Prover_state.proof} ->
          { Verifier.All_in_one.verification_key=M.verification_key; proof }))
    in
    Boolean.Assert.is_true (Verifier.All_in_one.result v)
  ;;
end

module Block0 = Block

let get_witness spec ~f =
  let open Main in
  store spec As_prover.(map get_state ~f)
;;

let unhash ~spec ~f ~to_bits h =
  let open Main in let open Let_syntax in
  let%bind b = get_witness spec ~f in
  let%bind h' = hash_digest (to_bits b) in
  let%map () = assert_equal h h' in
  b
;;

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
      { wrap_vk    : Other_curve.Verification_key.t
      ; prev_proof : Other_curve.Proof.t
      ; prev_state : State.value
      ; update     : Update.value
      }
    [@@deriving fields]
  end

  open Main
  open Let_syntax

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Main)(Main_curve)(Other_curve)
      (struct let input_size = Other.Data_spec.size (wrap_input ()) end)

  let input = step_input

  let wrap_vk_length = 0

  let wrap_vk_spec =
    Var_spec.list ~length:wrap_vk_length Boolean.spec

  let prev_state_valid wrap_vk prev_state =
    let%bind prev_state_hash =
      State.hash prev_state >>= Main.Digest.Checked.unpack
    in
    let%bind prev_top_hash =
      hash_digest (wrap_vk @ prev_state_hash) >>= Main.Digest.Checked.unpack
    in
    let%map v =
      Verifier.All_in_one.create ~verification_key:wrap_vk ~input:prev_top_hash
        As_prover.(map get_state ~f:(fun { Prover_state.prev_proof; wrap_vk } ->
          { Verifier.All_in_one.verification_key=wrap_vk; proof=prev_proof }))
    in
    Verifier.All_in_one.result v
  ;;

  let step top_hash =
    let%bind wrap_vk =
      get_witness wrap_vk_spec ~f:(fun { Prover_state.wrap_vk } ->
        Verifier.Verification_key.to_bool_list wrap_vk)
    in
    let%bind prev_state = get_witness State.spec ~f:Prover_state.prev_state
    and update          = get_witness Update.spec ~f:Prover_state.update
    in
    let%bind (next_state, `Success success) = Update.apply update prev_state in
    let%bind state_hash = State.hash next_state in
    let%bind () =
      let%bind sh = Main.Digest.Checked.unpack state_hash in
      hash_digest (wrap_vk @ sh) >>= assert_equal top_hash
    in
    let%bind prev_state_valid = prev_state_valid wrap_vk prev_state in
    let%bind inductive_case_passed = Boolean.(prev_state_valid && success) in
    let%bind is_base_case = State.is_base_hash state_hash in
    Boolean.Assert.any
      [ is_base_case
      ; inductive_case_passed
      ]
  ;;
end

module Step = struct
  module Pedersen0 = Pedersen.Main

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

    let fold_bits { difficulty_info; block_hash } ~init ~f =
      let init =
        List.fold difficulty_info ~init ~f:(fun init (time, target) -> 
          let init = Time.Unpacked.fold time ~init ~f in
          let init = Target.Unpacked.fold target ~init ~f in
          init)
      in
      Digest.Unpacked.fold block_hash ~init ~f
    ;;


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

    let to_bits ({ difficulty_info; block_hash } : value) : bool list =
      List.concat_map difficulty_info
        ~f:(fun (x, y) -> Time.Unpacked.to_bits x @ Target.Unpacked.to_bits y)
      @ Digest.(Unpacked.to_bits (unpack block_hash))
    ;;

    let base_state : value =
      let time = Block_time.of_time Core.Time.epoch in
      let target : Target.Unpacked.value =
        Target.unpack (Field.of_int (-1))
      in
      { difficulty_info =
          List.init difficulty_window ~f:(fun _ -> (time, target))
      ; block_hash = Block0.(hash genesis)
      }

    let hash t =
      let s = Pedersen0.State.create Pedersen0.params in
      Pedersen0.State.update_fold s (fold_bits t);
      Pedersen0.State.digest s
    ;;

    let base_hash = Cvar.constant (hash base_state)

    let is_base_hash h = Checked.equal base_hash h

    module Checked = struct
      let to_bits { difficulty_info; block_hash } =
        let%map bs = Digest.Checked.unpack block_hash in
        List.concat_map ~f:(fun (x, y) -> x @ y) difficulty_info @ bs

      let hash (t : var) = to_bits t >>= hash_digest 
    end

  end

  module Update = struct
    type var = Block.Packed.var
    type value = Block.Packed.value
    let spec : (var, value) Var_spec.t = Block.Packed.spec

    let all_but_last_exn xs = fst (split_last_exn xs)

    (* TODO *)
    let compute_target _ =
      return (Cvar.constant Field.(negate one))

    let () = assert
      (Target.bit_length = Digest.bit_length)

    let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
      let%map { less } = Util.compare ~bit_length:Target.bit_length target hash in
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

let step_keys = Main.generate_keypair (Transition.input ()) Transition.step
let step_vk = Main.Keypair.vk step_keys

module Wrap = Make_wrap(struct let verification_key = step_vk end)

let wrap_keys = Other.generate_keypair (Wrap.input ()) Wrap.main

