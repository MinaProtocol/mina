module Js = Js_of_ocaml.Js
module Backend = Kimchi_backend.Pasta.Vesta_based_plonk
module Impl = Pickles.Impls.Step
module Field = Impl.Field
module Boolean = Impl.Boolean
module Run_state = Snarky_backendless.Run_state

type field = Impl.field

module Poseidon : sig
  type sponge
end

val snarky :
  < run :
      < exists : (int -> (unit -> field array) -> Field.t array) Js.meth
      ; existsOne : ((unit -> field) -> Field.t) Js.meth
      ; inProver : (unit -> bool) Js.readonly_prop
      ; asProver : ((unit -> unit) -> unit) Js.meth
      ; inProverBlock : (unit -> bool Js.t) Js.readonly_prop
      ; setEvalConstraints : (bool -> unit) Js.readonly_prop
      ; enterConstraintSystem :
          (unit -> unit -> Backend.R1CS_constraint_system.t) Js.readonly_prop
      ; enterGenerateWitness :
          (unit -> unit -> Impl.Proof_inputs.t) Js.readonly_prop
      ; enterAsProver :
          (int -> field array option -> Field.t array) Js.readonly_prop
      ; state :
          < allocVar :
              (Backend.Run_state.t -> field Snarky_backendless.Cvar.t)
              Js.readonly_prop
          ; storeFieldElt :
              (Backend.Run_state.t -> field -> field Snarky_backendless.Cvar.t)
              Js.readonly_prop
          ; asProver : (Backend.Run_state.t -> bool) Js.readonly_prop
          ; setAsProver : (Backend.Run_state.t -> bool -> unit) Js.readonly_prop
          ; hasWitness : (Backend.Run_state.t -> bool) Js.readonly_prop
          ; getVariableValue :
              (Backend.Run_state.t -> int -> field) Js.readonly_prop >
          Js.t
          Js.readonly_prop >
      Js.t
      Js.readonly_prop
  ; constraintSystem :
      < rows : (Backend.R1CS_constraint_system.t -> int) Js.meth
      ; digest : (Backend.R1CS_constraint_system.t -> Js.js_string Js.t) Js.meth
      ; toJson : (Backend.R1CS_constraint_system.t -> 'a) Js.meth >
      Js.t
      Js.readonly_prop
  ; field :
      < assertEqual : (Field.t -> Field.t -> unit) Js.meth
      ; assertMul : (Field.t -> Field.t -> Field.t -> unit) Js.meth
      ; assertSquare : (Field.t -> Field.t -> unit) Js.meth
      ; assertBoolean : (Field.t -> unit) Js.meth
      ; compare :
          (int -> Field.t -> Field.t -> Boolean.var * Boolean.var) Js.meth
      ; readVar : (Field.t -> field) Js.meth
      ; truncateToBits16 :
          (   int
           -> field Snarky_backendless.Cvar.t
           -> field Snarky_backendless.Cvar.t )
          Js.meth >
      Js.t
      Js.readonly_prop
  ; gates :
      < zero : (Field.t -> Field.t -> Field.t -> unit) Js.meth
      ; generic :
          (   field
           -> Field.t
           -> field
           -> Field.t
           -> field
           -> Field.t
           -> field
           -> field
           -> unit )
          Js.meth
      ; poseidon : (Field.t array array -> unit) Js.meth
      ; ecAdd :
          (   Field.t * Field.t
           -> Field.t * Field.t
           -> Field.t * Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t * Field.t )
          Js.meth
      ; ecScale :
          (Field.t Kimchi_backend_common.Scale_round.t array -> unit) Js.meth
      ; ecEndoscale :
          (   Field.t Kimchi_backend_common.Endoscale_round.t array
           -> Field.t
           -> Field.t
           -> Field.t
           -> unit )
          Js.meth
      ; ecEndoscalar :
          (Field.t Kimchi_backend_common.Endoscale_scalar_round.t array -> unit)
          Js.meth
      ; lookup :
          (   Field.t * Field.t * Field.t * Field.t * Field.t * Field.t * Field.t
           -> unit )
          Js.meth
      ; rangeCheck0 :
          (   Field.t
           -> Field.t * Field.t * Field.t * Field.t * Field.t * Field.t
           -> Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
           -> field
           -> unit )
          Js.meth
      ; rangeCheck1 :
          (   Field.t
           -> Field.t
           -> Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
           -> Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
           -> unit )
          Js.meth
      ; xor :
          (   Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> Field.t
           -> unit )
          Js.meth
      ; foreignFieldAdd :
          (   Field.t * Field.t * Field.t
           -> Field.t * Field.t * Field.t
           -> Field.t
           -> Field.t
           -> field * field * field
           -> field
           -> unit )
          Js.meth
      ; foreignFieldMul :
          (   Field.t * Field.t * Field.t
           -> Field.t * Field.t * Field.t
           -> Field.t * Field.t
           -> Field.t * Field.t * Field.t
           -> Field.t
           -> Field.t * Field.t * Field.t
           -> Field.t
           -> Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
           -> Field.t * Field.t * Field.t * Field.t
           -> field
           -> field * field * field
           -> unit )
          Js.meth
      ; rotate :
          (   Field.t
           -> Field.t
           -> Field.t
           -> Field.t * Field.t * Field.t * Field.t
           -> Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
              * Field.t
           -> field
           -> unit )
          Js.meth
      ; addFixedLookupTable : (int32 -> field array array -> unit) Js.meth
      ; addRuntimeTableConfig : (int32 -> field array -> unit) Js.meth
      ; raw :
          (Kimchi_types.gate_type -> Field.t array -> field array -> unit)
          Js.meth >
      Js.t
      Js.readonly_prop
  ; group :
      < scaleFastUnpack :
          (   Field.t * Field.t
           -> Field.t Pickles_types.Shifted_value.Type1.t
           -> int
           -> (Field.t * Field.t) * Boolean.var array )
          Js.readonly_prop >
      Js.t
      Js.readonly_prop
  ; poseidon :
      < update :
          (   Field.t Random_oracle.State.t
           -> Field.t array
           -> Field.t Random_oracle.State.t )
          Js.meth
      ; hashToGroup :
          (   Field.t array
           -> field Snarky_backendless.Cvar.t * field Snarky_backendless.Cvar.t
          )
          Js.meth
      ; sponge :
          < absorb : (Poseidon.sponge -> Field.t -> unit) Js.meth
          ; create : (bool Js.t -> Poseidon.sponge) Js.meth
          ; squeeze : (Poseidon.sponge -> Field.t) Js.meth >
          Js.t
          Js.readonly_prop >
      Js.t
      Js.readonly_prop
  ; circuit :
      < compile :
          ((Field.t array -> unit) -> int -> bool -> Impl.Keypair.t) Js.meth
      ; keypair :
          < getConstraintSystemJSON : (Impl.Keypair.t -> 'a) Js.meth
          ; getVerificationKey :
              (Impl.Keypair.t -> Impl.Verification_key.t) Js.meth >
          Js.t
          Js.readonly_prop
      ; prove :
          (   (Field.t array -> unit)
           -> int
           -> field array
           -> Impl.Keypair.t
           -> Backend.Proof.with_public_evals )
          Js.meth
      ; verify :
          (   field array
           -> Backend.Proof.with_public_evals
           -> ( field
              , Kimchi_bindings.Protocol.SRS.Fp.t
              , Pasta_bindings.Fq.t Kimchi_types.or_infinity
                Kimchi_types.poly_comm )
              Kimchi_types.VerifierIndex.verifier_index
           -> bool Js.t )
          Js.meth >
      Js.t
      Js.readonly_prop >
  Js.t
