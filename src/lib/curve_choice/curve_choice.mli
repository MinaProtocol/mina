module Intf = Intf

module Cycle : sig
  module Mnt4 : Intf.Backend_intf

  module Mnt6 :
    Intf.Backend_intf
    with module Common.Field = Mnt4.Fq
    with module Fq = Mnt4.Common.Field
end

module Snarkette_tick : Intf.Snarkette_tick_intf

module Snarkette_tock : Intf.Snarkette_tock_intf

module Tick_full = Cycle.Mnt4
module Tock_full = Cycle.Mnt6

module Tick_backend : sig
  module Full = Tick_full

  include
    module type of Full.Default
    with module Field = Full.Default.Field
    with module Bigint = Full.Default.Bigint
    with module Proving_key = Full.Default.Proving_key
    with module Verification_key = Full.Default.Verification_key
    with module Keypair = Full.Default.Keypair
    with module Proof = Full.Default.Proof

  module Inner_curve : sig
    include
      module type of Tock_full.G1
      with type t = Tock_full.G1.t
       and type Affine.t = Tock_full.G1.Affine.t
       and type Vector.t = Tock_full.G1.Vector.t

    val find_y : Field.t -> Field.t option

    val point_near_x : Field.t -> t
  end

  module Inner_twisted_curve = Tock_full.G2
end

module Tick0 :
  Snarky.Snark_intf.S
  with type field = Tick_backend.Field.t
   and type Bigint.t = Tick_backend.Bigint.R.t
   and type R1CS_constraint_system.t = Tick_backend.R1CS_constraint_system.t
   and type Var.t = Tick_backend.Var.t
   and type Field.Vector.t = Tick_backend.Field.Vector.t
   and type Verification_key.t = Tick_backend.Verification_key.t
   and type Proving_key.t = Tick_backend.Proving_key.t
   and type Proof.t = Tick_backend.Proof.t
   and type Proof.message = Tick_backend.Proof.message

module Runners : sig
  module Tick :
    Snarky.Snark_intf.Run
    with type field = Tick_backend.Field.t
     and type prover_state = unit
     and type Bigint.t = Tick_backend.Bigint.R.t
     and type R1CS_constraint_system.t = Tick_backend.R1CS_constraint_system.t
     and type Var.t = Tick_backend.Var.t
     and type Field.Constant.Vector.t = Tick_backend.Field.Vector.t
     and type Verification_key.t = Tick_backend.Verification_key.t
     and type Proving_key.t = Tick_backend.Proving_key.t
     and type Proof.t = Tick_backend.Proof.t
     and type Proof.message = Tick_backend.Proof.message
end
