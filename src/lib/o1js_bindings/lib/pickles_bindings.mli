module Js = Js_of_ocaml.Js
module Impl = Pickles.Impls.Step
module Field = Impl.Field
module Boolean = Impl.Boolean

module Public_input : sig
  type t = Field.t array

  module Constant : sig
    type t = Field.Constant.t array
  end
end

type 'a statement = 'a array * 'a array

module Statement : sig
  type t = Field.t statement

  module Constant : sig
    type t = Field.Constant.t statement
  end
end

type proof = Pickles_types.Nat.N0.n Pickles.Proof.t

type pickles_rule_js =
  < identifier : Js.js_string Js.t Js.prop
  ; main :
      (   Public_input.t
       -> < publicOutput : Public_input.t Js.prop
          ; previousStatements : Statement.t array Js.prop
          ; previousProofs : proof array Js.prop
          ; shouldVerify : Boolean.var array Js.prop >
          Js.t
          Promise_js_helpers.js_promise )
      Js.prop
  ; featureFlags : bool option Pickles_types.Plonk_types.Features.t Js.prop
  ; proofsToVerify :
      < isSelf : bool Js.t Js.prop ; tag : Js.Unsafe.any Js.t Js.prop > Js.t
      array
      Js.prop >
  Js.t

module Cache : sig
  type js_storable
end

module Proof0 : sig
  type t = Pickles_types.Nat.N0.n Pickles.Proof.t
end

module Proof1 : sig
  type t = Pickles_types.Nat.N1.n Pickles.Proof.t
end

module Proof2 : sig
  type t = Pickles_types.Nat.N2.n Pickles.Proof.t
end

type some_proof = Proof0 of Proof0.t | Proof1 of Proof1.t | Proof2 of Proof2.t

val pickles :
  < compile :
      (   pickles_rule_js array
       -> < publicInputSize : int Js.prop
          ; publicOutputSize : int Js.prop
          ; storable : Cache.js_storable Js.optdef_prop
          ; overrideWrapDomain : int Js.optdef_prop
          ; numChunks : int Js.optdef_prop
          ; lazyMode : bool Js.optdef_prop >
          Js.t
       -> < getVerificationKey :
              (   unit
               -> (Js.js_string Js.t * Impl.field) Promise_js_helpers.js_promise
              )
              Js.readonly_prop
          ; provers : 'a Js.readonly_prop
          ; tag : 'b Js.readonly_prop
          ; verify : 'c Js.readonly_prop >
          Js.t )
      Js.readonly_prop
  ; verify :
      (   Statement.Constant.t
       -> proof
       -> Js.js_string Js.t
       -> bool Js.t Promise_js_helpers.js_promise )
      Js.readonly_prop
  ; loadSrsFp : (unit -> Kimchi_bindings.Protocol.SRS.Fp.t) Js.readonly_prop
  ; loadSrsFq : (unit -> Kimchi_bindings.Protocol.SRS.Fq.t) Js.readonly_prop
  ; dummyProof : (int -> int -> some_proof) Js.readonly_prop
  ; dummyVerificationKey :
      (unit -> Js.js_string Js.t * Impl.field) Js.readonly_prop
  ; encodeVerificationKey :
      (Pickles.Verification_key.t -> Js.js_string Js.t) Js.readonly_prop
  ; decodeVerificationKey :
      (Js.js_string Js.t -> Pickles.Verification_key.t) Js.readonly_prop
  ; proofOfBase64 : (Js.js_string Js.t -> int -> some_proof) Js.readonly_prop
  ; proofToBase64 : (some_proof -> Js.js_string Js.t) Js.readonly_prop
  ; proofToBase64Transaction : (proof -> Js.js_string Js.t) Js.readonly_prop
  ; util :
      < fromMlString : (string -> Js.js_string Js.t) Js.readonly_prop
      ; toMlString : (Js.js_string Js.t -> string) Js.readonly_prop >
      Js.t
      Js.readonly_prop
  ; sideLoaded :
      < create :
          (   Js.js_string Js.t
           -> int
           -> int
           -> int
           -> bool option Pickles_types.Plonk_types.Features.t
           -> 'd )
          Js_of_ocaml.Js.readonly_prop
      ; inCircuit :
          (   _ Pickles.Tag.t
           -> Mina_wire_types.Pickles.M.Side_loaded.Verification_key.V2.t
           -> unit )
          Js_of_ocaml.Js.readonly_prop
      ; inProver :
          (_ Pickles.Tag.t -> Js.js_string Js.t -> unit)
          Js_of_ocaml.Js.readonly_prop
      ; vkDigest :
          (   Pickles.Side_loaded.Verification_key.Checked.t
           -> Pickles.Impls.Step.Internal_Basic.Field.Var.t array )
          Js_of_ocaml.Js.readonly_prop
      ; vkToCircuit :
          (   (unit -> Js.js_string Js.t)
           -> Pickles.Side_loaded.Verification_key.Checked.t )
          Js_of_ocaml.Js.readonly_prop >
      Js.t
      Js_of_ocaml.Js.readonly_prop >
  Js.t
