open Core_kernel
open Async_kernel
open Util
open Nanobit_base
open Snark_params

module State = struct
  open Tick
  open Let_syntax

  module Digest = Pedersen.Digest

  let difficulty_window = 17

  let all_but_last_exn xs = fst (split_last_exn xs)

  (* Someday: It may well be worth using bitcoin's compact nbits for target values since
    targets are quite chunky *)
  type ('time, 'target, 'digest, 'number, 'strength) t_ =
    { difficulty_info : ('time * 'target) list
    ; block_hash      : 'digest
    ; number          : 'number
    ; strength        : 'strength
    }
  [@@deriving bin_io]

  type t = (Block_time.t, Target.t, Digest.t, Block.Body.t, Strength.t) t_
  [@@deriving bin_io]

  type var =
    ( Block_time.Unpacked.var
    , Target.Unpacked.var
    , Digest.Packed.var
    , Block.Body.Packed.var
    , Strength.Packed.var
    ) t_

  type value =
    ( Block_time.Unpacked.value
    , Target.Unpacked.value
    , Digest.Packed.value
    , Block.Body.Packed.value
    , Strength.Packed.value
    ) t_

  let to_hlist { difficulty_info; block_hash; number; strength } = H_list.([ difficulty_info; block_hash; number; strength ])
  let of_hlist = H_list.(fun [ difficulty_info; block_hash; number; strength ] -> { difficulty_info; block_hash; number; strength })

  let data_spec =
    let open Data_spec in
    [ Var_spec.(
        list ~length:difficulty_window
          (tuple2 Block_time.Unpacked.spec Target.Unpacked.spec))
    ; Digest.Packed.spec
    ; Block.Body.Packed.spec
    ; Strength.Packed.spec
    ]

  let spec : (var, value) Var_spec.t =
    Var_spec.of_hlistable data_spec
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let compute_target_unchecked _ : Target.t = 
    Target.of_field Field.(negate one)

  let compute_target = compute_target_unchecked

  let update_exn (state : value) (block : Block.t) =
    let target = compute_target_unchecked state.difficulty_info in
    let block_hash = Block.hash block in
    assert (Target.meets_target target ~hash:block_hash);
    let strength = Target.strength_unchecked target in
    assert Int64.(block.body > state.number);
    { difficulty_info =
        (block.header.time, target)
        :: all_but_last_exn state.difficulty_info
    ; block_hash
    ; number = block.body
    ; strength = Field.add strength state.strength
    }

  let negative_one : value =
    let time = Block_time.of_time Core.Time.epoch in
    let target : Target.Unpacked.value =
      Target.(unpack (of_field (Field.of_int (-1))))
    in
    { difficulty_info =
        List.init difficulty_window ~f:(fun _ -> (time, target))
    ; block_hash = Block.genesis.header.previous_block_hash
    ; number = Int64.of_int 0
    ; strength = Strength.zero
    }

  let zero = update_exn negative_one Block.genesis 

  let to_bits ({ difficulty_info; block_hash; number; strength } : var) =
    let%map h = Digest.Checked.(unpack block_hash >>| to_bits)
    and n = Block.Body.Checked.(unpack number >>| to_bits)
    and s = Strength.Checked.(unpack strength >>| to_bits)
    in
    List.concat_map difficulty_info ~f:(fun (x, y) ->
      Block_time.Checked.to_bits x @ Target.Checked.to_bits y)
    @ h
    @ n
    @ s

  let to_bits_unchecked ({ difficulty_info; block_hash; number; strength } : value) =
    let h = Digest.(Unpacked.to_bits (unpack block_hash)) in
    let n = Block.Body.(Unpacked.to_bits (unpack number)) in
    let s = Strength.(Unpacked.to_bits (unpack strength)) in
    List.concat_map difficulty_info ~f:(fun (x, y) ->
      Block_time.Bits.to_bits x @ Target.Unpacked.to_bits y)
    @ h
    @ n
    @ s

  let hash t =
    let s = Pedersen.State.create Pedersen.params in
    Pedersen.State.update_fold s
      (List.fold_left (to_bits_unchecked t))
    |> Pedersen.State.digest

  let zero_hash = hash zero

  module Checked = struct
    let is_base_hash h = Checked.equal (Cvar.constant zero_hash) h

    let hash (t : var) = to_bits t >>= hash_digest

    (* TODO: A subsequent PR will replace this with the actual difficulty calculation *)
    let compute_target _ = return (Cvar.constant Field.(negate one))

    let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
      with_label "meets_target" begin
        let%map { less } =
          Util.compare ~bit_length:Field.size_in_bits hash (target :> Cvar.t)
        in
        less
      end

    let valid_body ~prev body =
      with_label "valid_body" begin
        let%bind { less } = Util.compare ~bit_length:Block.Body.bit_length prev body in
        Boolean.Assert.is_true less
      end
    ;;

    let update (state : var) (block : Block.Packed.var) =
      with_label "Blockchain.State.update" begin
        let%bind () =
          assert_equal ~label:"previous_block_hash"
            block.header.previous_block_hash state.block_hash
        in
        let%bind () = valid_body ~prev:state.number block.body in
        let%bind target = compute_target state.difficulty_info in
        let%bind target_unpacked = Target.Checked.unpack target in
        let%bind strength = Target.strength target target_unpacked in
        let%bind block_unpacked = Block.Checked.unpack block in
        let%bind block_hash =
          let bits = Block.Checked.to_bits block_unpacked in
          hash_digest bits
        in
        let%map meets_target = meets_target target block_hash in
        ( { difficulty_info =
              (block_unpacked.header.time, target_unpacked)
              :: all_but_last_exn state.difficulty_info
          ; block_hash
          ; number = block.body
          ; strength = Cvar.Infix.(strength + state.strength)
          }
        , `Success meets_target
        )
      end
  end
end

type t =
  { state : State.t
  ; proof : Proof.t
  }
[@@deriving bin_io]

module Update = struct
  type nonrec t =
    | New_chain of t
end

let valid t =
  if Snark_params.insecure_mode
  then true
  else failwith "TODO"

let accumulate ~init ~updates ~strongest_chain =
  don't_wait_for begin
    let%map _last_block =
      Linear_pipe.fold updates ~init ~f:(fun chain (Update.New_chain new_chain) ->
        if not (valid new_chain)
        then return chain
        else if Strength.(new_chain.state.strength > chain.state.strength)
        then 
          let%map () = Pipe.write strongest_chain new_chain in
          new_chain
        else
          return chain)
    in
    ()
  end

module Digest = Tick.Pedersen.Digest

module System = struct
  module State = State
  module Update = Block.Packed
end

module Transition =
  Transition_system.Make
    (struct
      module Tick = Digest
      module Tock = Bits.Snarkable.Field(Tock)
    end)
    (struct let hash = Tick.hash_digest end)
    (System)

let base_hash =
  if Snark_params.insecure_mode
  then Tick.Field.zero
  else Transition.instance_hash System.State.zero

module Step = Transition.Step
module Wrap = Transition.Wrap

let base_proof =
  if Snark_params.insecure_mode
  then begin
    let s = "0H\150A)W\135\192\t5\202\159\194\193\195s)w\1808o\1578\015zK\1278\234\152\226\020\204\237\204SUo\002\000\00010\226<\229]\252_\198\001$\174\166o\225\189i\230\255F\"\251\214\197\004\224\190nI\181c\174\210\156\140)\160\204z\003\000\00000\144\021\255\207\024\183P\1670\200Fyk\131\191\015\140e]v\\\022\218MHJ\028\213bO:1)\137\242\130C\001\000\000\128\151\000H\135\019;/B\186\152\204\254f\131\179\018\156=$\243\211\140\166\217\011r4]\240_K\144\158;\000\177\002\000\00010\149\208\232\188W\200\191\253Q\023\151M\215\024\149E\237s\185\187j\219\224d\146\147l>\201\152\021s\140\240\152\168\006\002\000\00000\224e]n`\245U\002\207\198\170(0\217\247j.`\144\"\169\221\161\241\162.\226\002N+\231K\185\137}:\007\001\000\00010\249V\197\226\201\202\173\146\196\178\168\005\198p\163B\166\020H\
             \nE\022\250\252\151\140\253\242a|\162t\220\179\227\213p\001\000\00010e#^E\133n\177\2216sl\020\244\170\004\139\219\228\139\227Oft\231\144\184\127\001\1689a?\184\0232\021\131\002\000\00010\133e\197Lm\204\180\193\232\237[\193\195\175%\226\247\024z\132\144=\022\230\228\019}\145(QN\160mE\235V\238\000\000\0001"
    in
    Tick_curve.Proof.of_string s
  end else begin
    let dummy_proof =
      let open Tock in
      let input = Data_spec.[] in
      let main =
        let one = Cvar.constant Field.one in
        assert_equal one one
      in
      let keypair = generate_keypair input main in
      prove (Keypair.pk keypair) input () main
    in
    Tick.prove (Lazy.force Step.proving_key) (Step.input ())
      { Step.Prover_state.prev_proof = dummy_proof
      ; wrap_vk  = Lazy.force Wrap.verification_key
      ; prev_state = System.State.negative_one
      ; update = Block.genesis
      }
      Step.main
      base_hash
  end
;;

let genesis = { state = State.zero; proof = base_proof }

let extend_exn { state=prev_state; proof=prev_proof } block =
  let proof =
    if Snark_params.insecure_mode
    then base_proof
    else Transition.step ~prev_proof ~prev_state block
  in
  { proof; state = State.update_exn prev_state block }
;;

