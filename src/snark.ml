open Core_kernel
open Util
open Snark_params

module Digest = Snark_params.Main.Pedersen.Digest

module Main = struct
  include Snark_params.Main

end

module Block0 = Block

module System = struct
  open Main
  open Let_syntax

  module State = Blockchain.State
  module Update = Block.Packed
end

module Transition =
  Transition_system.Make
    (struct
      module Main = Digest
      module Other = Bits.Snarkable.Field(Other)
    end)
    (struct let hash = Main.hash_digest end)
    (System)

module Step = Transition.Step
module Wrap = Transition.Wrap

let base_hash =
  Transition.instance_hash System.State.zero

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
  Main.prove Step.proving_key (Step.input ())
    { Step.Prover_state.prev_proof = dummy_proof
    ; wrap_vk  = Wrap.verification_key
    ; prev_state = System.State.negative_one
    ; update = Block.genesis
    }
    Step.main
    base_hash

let () =
  assert
    (Main.verify base_proof Step.verification_key
       (Step.input ()) base_hash)
;;

