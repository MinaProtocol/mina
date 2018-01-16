open Core_kernel
open Util
open Snark_params

let bitstring xs =
  String.of_char_list (List.map xs ~f:(fun b -> if b then '1' else '0'))

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

let wrap_input () =
  let open Other in
  let open Data_spec in
  [ Var_spec.field ]

module Make_wrap (M : sig
    val verification_key : Main.Verification_key.t
  end)
= struct
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

  let wrap_vk_length = 11324

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

  let print_bool ~label (b : Boolean.var) =
    as_prover
      As_prover.(map (read Boolean.spec b) ~f:(fun b -> printf "%s: %b\n%!" label b))

  let main top_hash =
    let%bind wrap_vk =
      get_witness wrap_vk_spec ~f:(fun { Prover_state.wrap_vk } ->
        Verifier.Verification_key.to_bool_list wrap_vk)
    in
    let%bind prev_state = get_witness State.spec ~f:Prover_state.prev_state
    and update          = get_witness Update.spec ~f:Prover_state.update
    in
    let%bind (next_state, `Success success) = Update.apply update prev_state in
    let%bind () = print_bool ~label:"success" success in
    let%bind state_hash = State.hash next_state in
    let%bind () =
      let%bind () =
        as_prover As_prover.(map (read_var state_hash) ~f:(fun x ->
          printf "in proof, state_hash\n%!";
          Field.print x))
      in
      let%bind sh = Main.Digest.Checked.unpack state_hash in
      hash_digest (wrap_vk @ sh) >>= assert_equal ~label:"equal_to_top_hash" top_hash
    in
    let%bind prev_state_valid = prev_state_valid wrap_vk prev_state in
    printf "TEST\n%!";
    let%bind () = print_bool ~label:"prev_state_valid" prev_state_valid in
    let%bind inductive_case_passed = Boolean.(prev_state_valid && success) in
    let%bind () = print_bool ~label:"inductive_case_passed" inductive_case_passed in
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


  let compute_target_unchecked _ = Field.(negate one)

  let all_but_last_exn xs = fst (split_last_exn xs)

  module State = struct
    let difficulty_window = 17

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

    let apply_unchecked (block : Block0.t) state =
      let target = compute_target_unchecked state.difficulty_info in
      let block_hash = Block0.hash block in
      { difficulty_info =
          (block.header.time, target)
          :: all_but_last_exn state.difficulty_info
      ; block_hash
      }

    let state_negative_one : value =
      let time = Block_time.of_time Core.Time.epoch in
      let target : Target.Unpacked.value =
        Target.unpack (Field.of_int (-1))
      in
      { difficulty_info =
          List.init difficulty_window ~f:(fun _ -> (time, target))
      ; block_hash = Block0.(hash genesis)
      }

    let state_zero  =
      apply_unchecked Block0.genesis state_negative_one

    let hash_unchecked t =
      let s = Pedersen0.State.create Pedersen0.params in
      Pedersen0.State.update_fold s (fold_bits t);
      Pedersen0.State.digest s

    let base_hash = hash_unchecked state_zero

    let is_base_hash h = Checked.equal (Cvar.constant base_hash) h

    let to_bits { difficulty_info; block_hash } =
      let%map bs = Digest.Checked.unpack block_hash in
      List.concat_map ~f:(fun (x, y) -> x @ y) difficulty_info
      @ bs

    let hash (t : var) = to_bits t >>= hash_digest 
  end

  module Update = struct
    type var = Block.Packed.var
    type value = Block.Packed.value
    let spec : (var, value) Var_spec.t = Block.Packed.spec

    (* TODO: A subsequent PR will replace this with the actual difficulty calculation *)
    let compute_target _ =
      return (Cvar.constant Field.(negate one))

    let apply_unchecked = State.apply_unchecked

    let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
      let%map { less } = Util.compare ~bit_length:Field.size_in_bits target hash in
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

module Step_keys = struct
  type t =
    { vk : Main.Verification_key.t
    ; pk : Main.Proving_key.t
    }

  let to_string { vk; pk } =
    let ss =
      [ Main.Verification_key.to_string vk
      ; Main.Proving_key.to_string pk
      ]
    in
    Sexp.to_string ([%sexp_of: string list] ss)
  ;;

  let of_string s =
    match Sexp.of_string_conv_exn s [%of_sexp: string list] with
    | [ vk; pk ] ->
      { vk = Main.Verification_key.of_string vk
      ; pk = Main.Proving_key.of_string pk
      }
    | _ -> failwith "Step_keys.of_string"
end

(*
module Keys = struct
  type t =
    { wrap_vk : Other.Verification_key.t
    ; wrap_pk : Other.Proving_key.t
    ; step_vk : Main.Verification_key.t
    ; step_pk : Main.Proving_key.t
    }

  let to_string { wrap_vk; wrap_pk; step_vk; step_pk } =
    let ss =
      [ Other.Verification_key.to_string wrap_vk
      ; Other.Proving_key.to_string wrap_pk
      ; Main.Verification_key.to_string step_vk
      ; Main.Proving_key.to_string step_pk
      ]
    in
    Sexp.to_string ([%sexp_of: string list] ss)
  ;;

  let of_string s =
    match Sexp.of_string_conv_exn s [%of_sexp: string list] with
    | [ wrap_vk; wrap_pk; step_vk; step_pk ] ->
      { wrap_vk = Other.Verification_key.of_string wrap_vk
      ; wrap_pk = Other.Proving_key.of_string wrap_pk
      ; step_vk = Main.Verification_key.of_string step_vk
      ; step_pk = Main.Proving_key.of_string step_pk
      }
    | _ -> failwith "Keys.of_string"
end *)

let load_keys_start = Time.now ()

let { Step_keys.vk=step_vk; pk=step_pk } =
  let maybe_read path k =
    if Sys.file_exists path
    then
      let s = In_channel.read_all path in
      printf "Read file\n%!";
      Some (k s)
    else None
  in
  let path = "step_keys" in
  (*
  match maybe_read path Step_keys.of_string with
  | Some keys -> keys
  | None -> *)
    let kp = Main.generate_keypair (Transition.input ()) Transition.main in
    let keys =
      { Step_keys.vk = Main.Keypair.vk kp
      ; pk = Main.Keypair.pk kp
      }
    in
(*     Out_channel.write_all path ~data:(Step_keys.to_string keys); *)
    keys
;;

let () =
  printf "Loaded keys (%s)\n%!"
    (Time.Span.to_string_hum (Time.diff (Time.now ()) load_keys_start))

module Wrap = Make_wrap(struct let verification_key = step_vk end)

let wrap_keys = Other.generate_keypair (Wrap.input ()) Wrap.main
let wrap_vk = Other.Keypair.vk wrap_keys
let wrap_pk = Other.Keypair.pk wrap_keys

let base_proof =
  let dummy_proof =
    let open Other in
    let input = Data_spec.[] in
    let main =
      let one = Cvar.constant Field.one in
      assert_equal one one
    in
    let keypair = generate_keypair input main in
    prove (Keypair.pk keypair) input () main
  in
  let base_hash =
    let open Pedersen.Main in
    let self = Transition.Verifier.Verification_key.to_bool_list wrap_vk in
    let s = State.create params in
    State.update_fold s (List.fold self);
    State.update_fold s (List.fold (Digest.Bits.to_bits Step.State.base_hash));
    State.digest s
  in
  let () =
    printf "state-base-hash\n%!";
    Main.Field.print Step.State.base_hash;
    printf "top-base-hash\n%!";
    Main.Field.print base_hash;
  in
  Main.prove step_pk (Transition.input ())
    { Transition.Prover_state.prev_proof = dummy_proof
    ; wrap_vk 
    ; prev_state = Step.State.state_negative_one
    ; update = Block.genesis
    }
    Transition.main
    base_hash (* This shouldn't have worked. This should be H(self, base_hash) *)
;;

let embed (x : Main.Field.t) : Other.Field.t =
  let n = Main.Bigint.of_field x in
  let rec go pt acc i =
    if i = Main.Field.size_in_bits
    then acc
    else
      go (Other.Field.add pt pt)
        (if Main.Bigint.test_bit n i
         then Other.Field.add pt acc
         else acc)
        (i + 1)
  in
  go Other.Field.one Other.Field.zero 0
;;

let wrap (hash : Pedersen.Main.Digest.t) proof =
  Other.prove wrap_pk (Wrap.input ())
    { Wrap.Prover_state.proof }
    Wrap.main
    (embed hash)
;;

let step ~prev_proof ~prev_state block =
  let prev_hash = Step.State.hash_unchecked prev_state in
  let prev_proof = wrap prev_hash prev_proof in
  let next_state = Step.Update.apply_unchecked block prev_state in
  Main.prove step_pk (Transition.input ())
    { Transition.Prover_state.prev_proof
    ; wrap_vk
    ; prev_state
    ; update = block
    }
    Transition.main
    (Step.State.hash_unchecked next_state)
;;

let proof =
  step ~prev_proof:base_proof ~prev_state:Step.State.state_zero
