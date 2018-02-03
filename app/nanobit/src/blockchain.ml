open Core_kernel
open Async_kernel
open Util
open Nanobit_base
open Snark_params

module State = Blockchain_state

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

module Transition = Nanobit_base.Blockchain_transition

module Transition_utils = struct
  open Transition_keys

  let instance_hash =
    let self =
      Step.Verifier.Verification_key.to_bool_list Wrap.verification_key
    in
    fun state ->
      let open Tick.Pedersen in
      let s = State.create params in
      let s = State.update_fold s (List.fold self) in
      let s =
        State.update_fold s
          (List.fold
            (Digest.Bits.to_bits
               (Blockchain_state.hash state)))
      in
      State.digest s

  let wrap : Tick.Pedersen.Digest.t -> Tick.Proof.t -> Tock.Proof.t =
    let embed (x : Tick.Field.t) : Tock.Field.t =
      let n = Tick.Bigint.of_field x in
      let rec go pt acc i =
        if i = Tick.Field.size_in_bits
        then acc
        else
          go (Tock.Field.add pt pt)
            (if Tick.Bigint.test_bit n i
            then Tock.Field.add pt acc
            else acc)
            (i + 1)
      in
      go Tock.Field.one Tock.Field.zero 0
    in
    fun hash proof ->
      Tock.prove Wrap.proving_key (Wrap.input ())
        { Wrap.Prover_state.proof }
        Wrap.main
        (embed hash)

  let step ~prev_proof ~prev_state block =
    let prev_proof = wrap (instance_hash prev_state) prev_proof in
    let next_state = State.update_exn prev_state block in
    Tick.prove Step.proving_key (Step.input ())
      { Step.Prover_state.prev_proof
      ; wrap_vk = Wrap.verification_key
      ; prev_state
      ; update = block
      }
      Step.main
      (instance_hash next_state)
end

let base_hash =
  if Snark_params.insecure_mode
  then Tick.Field.zero
  else Transition_utils.instance_hash State.zero

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
    Tick.prove (Transition_keys.Step.proving_key) (Transition_keys.Step.input ())
      { Transition_keys.Step.Prover_state.prev_proof = dummy_proof
      ; wrap_vk  = Transition_keys.Wrap.verification_key
      ; prev_state = State.negative_one
      ; update = Block.genesis
      }
      Transition_keys.Step.main
      base_hash
  end
;;

let genesis = { state = State.zero; proof = base_proof }

let extend_exn { state=prev_state; proof=prev_proof } block =
  let proof =
    if Snark_params.insecure_mode
    then base_proof
    else Transition_utils.step ~prev_proof ~prev_state block
  in
  { proof; state = State.update_exn prev_state block }
;;

