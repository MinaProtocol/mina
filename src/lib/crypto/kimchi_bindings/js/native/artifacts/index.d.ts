// Header section
// To edit this section, look for
// ./src/lib/crypto/kimchi_bindings/js/native/header-d.ts
// This file gets auto-included in the generated kimchi-napi types to supplement
// external pointer types. These are opaque handles to Rust-owned values; the
// exported names are consumed by o1js (src/bindings/crypto/native/*.ts).

export type WasmPastaFp = Uint8Array;
export type WasmPastaFq = Uint8Array;
type Proof = {};
export type WasmVector<T> = {};
// flat vectors of field elements cross the FFI boundary as a single byte array
export type WasmFlatVector<T> = Uint8Array;
type Self = {};

// Aliases referenced by generated signatures that the type-def generator does
// not resolve to concrete declarations.
export type NapiGVesta = WasmGVesta;
export type NapiGPallas = WasmGPallas;
export type NapiPastaFp = WasmPastaFp;
export type NapiPastaFq = WasmPastaFq;
export type NapiVector<T> = WasmVector<T>;
export type NapiFlatVector<T> = WasmFlatVector<T>;
export type NapiLookupInfo = WasmLookupInfo;
export type NapiPastaFpPlonkIndex = WasmPastaFpPlonkIndex;
export type NapiPastaFqPlonkIndex = WasmPastaFqPlonkIndex;
export type NapiDomain = {};
export type NapiFpRuntimeTable = {};
export type NapiFqRuntimeTable = {};
export type NapiLookupCommitments = {};
export type NapiLookupSelectors = {};
export type NapiLookupVerifierIndex = {};
export type NapiOpeningProof = {};
export type NapiPlonkVerificationEvals = {};
export type NapiPlonkVerifierIndex = WasmFpPlonkVerifierIndex | WasmFqPlonkVerifierIndex;
export type NapiPointEvaluations = {};
export type NapiPolyComm = {};
export type NapiProofEvaluations = {};
export type NapiProofF = {};
export type NapiProverCommitments = {};
export type NapiRandomOracles = {};
export type NapiShifts = {};
export type WasmPlonkVerifierIndex = {};
export type WasmPolyComm = {};
export type WasmProverProof = {};

// Header section end

export declare class ExternalObject<T> {
  readonly '': {
    readonly '': unique symbol
    [K: symbol]: T
  }
}
export declare class WasmFpGateVector {
  constructor()
  serialize(): Uint8Array
  static deserialize(bytes: Uint8Array): WasmFpGateVector
}
export type NapiFpGateVector = WasmFpGateVector

export declare class WasmFpLookupCommitments {
  constructor(sorted: NapiVector<WasmFpPolyComm>, aggreg: WasmFpPolyComm, runtime?: WasmFpPolyComm | undefined | null)
  get sorted(): NapiVector<WasmFpPolyComm>
  get aggreg(): WasmFpPolyComm
  get runtime(): WasmFpPolyComm | null
  set set_sorted(s: NapiVector<WasmFpPolyComm>)
  set set_aggreg(a: WasmFpPolyComm)
  set set_runtime(r?: WasmFpPolyComm | undefined | null)
}
export type NapiFpLookupCommitments = WasmFpLookupCommitments

export declare class WasmFpOpeningProof {
  z1: NapiPastaFp
  z2: NapiPastaFp
  constructor(lr0: NapiVector<NapiGVesta>, lr1: NapiVector<NapiGVesta>, delta: NapiGVesta, z1: NapiPastaFp, z2: NapiPastaFp, sg: NapiGVesta)
  get lr_0(): NapiVector<NapiGVesta>
  get lr_1(): NapiVector<NapiGVesta>
  get delta(): NapiGVesta
  get sg(): NapiGVesta
  set set_lr_0(lr0: NapiVector<NapiGVesta>)
  set set_lr_1(lr1: NapiVector<NapiGVesta>)
  set set_delta(delta: NapiGVesta)
  set set_sg(sg: NapiGVesta)
}
export type NapiFpOpeningProof = WasmFpOpeningProof

export declare class WasmFpOracles {
  o: WasmFpRandomOracles
  p_eval0: NapiPastaFp
  p_eval1: NapiPastaFp
  digest_before_evaluations: NapiPastaFp
  constructor(o: NapiRandomOracles, pEval0: NapiPastaFp, pEval1: NapiPastaFp, openingPrechallenges: NapiFlatVector<NapiPastaFp>, digestBeforeEvaluations: NapiPastaFp)
  get opening_prechallenges(): NapiFlatVector<NapiPastaFp>
  set set_opening_prechallenges(x: NapiFlatVector<NapiPastaFp>)
}
export type NapiFpOracles = WasmFpOracles

export declare class WasmFpPolyComm {
  constructor(unshifted: NapiVector<NapiGVesta>, shifted?: NapiGVesta | undefined | null)
  get unshifted(): NapiVector<NapiGVesta>
  set set_unshifted(x: NapiVector<NapiGVesta>)
  get shifted(): NapiGVesta | null
  set set_shifted(value?: NapiGVesta | undefined | null)
}
export type NapiFpPolyComm = WasmFpPolyComm

export declare class WasmFpProverCommitments {
  constructor(wComm: NapiVector<WasmFpPolyComm>, zComm: WasmFpPolyComm, tComm: WasmFpPolyComm, lookup?: NapiLookupCommitments | undefined | null)
  get w_comm(): NapiVector<WasmFpPolyComm>
  get z_comm(): WasmFpPolyComm
  get t_comm(): WasmFpPolyComm
  get lookup(): NapiLookupCommitments | null
  set set_w_comm(x: NapiVector<WasmFpPolyComm>)
  set set_z_comm(x: WasmFpPolyComm)
  set set_t_comm(x: WasmFpPolyComm)
  set set_lookup(l?: NapiLookupCommitments | undefined | null)
}
export type NapiFpProverCommitments = WasmFpProverCommitments

export declare class WasmFpProverProof {
  /**
   * Drop the heavy proof contents by replacing them with a small
   * dummy. Rust memory behind napi objects is normally freed only
   * when the JS GC runs the wrapper's finalizer, which on wasm32
   * can be far too late (4 GiB ceiling, see o1js AGENT_LOG.md) —
   * callers that are done with a proof free it deterministically.
   */
  free(): void
  constructor(commitments: NapiProverCommitments, proof: NapiOpeningProof, evals: NapiProofEvaluations, ftEval1: NapiPastaFp, public: NapiFlatVector<NapiPastaFp>, prevChallengesScalars: NapiVecVecFp, prevChallengesComms: NapiVector<WasmFpPolyComm>)
  get commitments(): NapiProverCommitments
  get proof(): NapiOpeningProof
  get evals(): NapiProofEvaluations
  get ft_eval1(): NapiPastaFp
  get public_(): NapiFlatVector<NapiPastaFp>
  get prev_challenges_scalars(): NapiVecVecFp
  get prev_challenges_comms(): NapiVector<WasmFpPolyComm>
  set set_commitments(commitments: NapiProverCommitments)
  set set_proof(proof: NapiOpeningProof)
  set set_evals(evals: NapiProofEvaluations)
  set set_ft_eval1(ftEval1: NapiPastaFp)
  set set_public_(public: NapiFlatVector<NapiPastaFp>)
  set set_prev_challenges_scalars(prevChallengesScalars: NapiVecVecFp)
  set set_prev_challenges_comms(prevChallengesComms: NapiVector<WasmFpPolyComm>)
  serialize(): string
}
export type NapiFpProverProof = WasmFpProverProof

export declare class WasmFpRandomOracles {
  joint_combiner_chal?: NapiPastaFp
  joint_combiner?: NapiPastaFp
  beta: NapiPastaFp
  gamma: NapiPastaFp
  alpha_chal: NapiPastaFp
  alpha: NapiPastaFp
  zeta: NapiPastaFp
  v: NapiPastaFp
  u: NapiPastaFp
  zeta_chal: NapiPastaFp
  v_chal: NapiPastaFp
  u_chal: NapiPastaFp
  constructor(jointCombinerChal: NapiPastaFp | undefined | null, jointCombiner: NapiPastaFp | undefined | null, beta: NapiPastaFp, gamma: NapiPastaFp, alphaChal: NapiPastaFp, alpha: NapiPastaFp, zeta: NapiPastaFp, v: NapiPastaFp, u: NapiPastaFp, zetaChal: NapiPastaFp, vChal: NapiPastaFp, uChal: NapiPastaFp)
}
export type NapiFpRandomOracles = WasmFpRandomOracles

export declare class WasmFpSrs {
  serialize(): Uint8Array
  static deserialize(bytes: Uint8Array): WasmFpSrs
}
export type NapiFpSrs = WasmFpSrs

export declare class WasmFqGateVector {
  constructor()
  serialize(): Uint8Array
  static deserialize(bytes: Uint8Array): WasmFqGateVector
}
export type NapiFqGateVector = WasmFqGateVector

export declare class WasmFqLookupCommitments {
  constructor(sorted: NapiVector<WasmFqPolyComm>, aggreg: WasmFqPolyComm, runtime?: WasmFqPolyComm | undefined | null)
  get sorted(): NapiVector<WasmFqPolyComm>
  get aggreg(): WasmFqPolyComm
  get runtime(): WasmFqPolyComm | null
  set set_sorted(s: NapiVector<WasmFqPolyComm>)
  set set_aggreg(a: WasmFqPolyComm)
  set set_runtime(r?: WasmFqPolyComm | undefined | null)
}
export type NapiFqLookupCommitments = WasmFqLookupCommitments

export declare class WasmFqOpeningProof {
  z1: NapiPastaFq
  z2: NapiPastaFq
  constructor(lr0: NapiVector<NapiGPallas>, lr1: NapiVector<NapiGPallas>, delta: NapiGPallas, z1: NapiPastaFq, z2: NapiPastaFq, sg: NapiGPallas)
  get lr_0(): NapiVector<NapiGPallas>
  get lr_1(): NapiVector<NapiGPallas>
  get delta(): NapiGPallas
  get sg(): NapiGPallas
  set set_lr_0(lr0: NapiVector<NapiGPallas>)
  set set_lr_1(lr1: NapiVector<NapiGPallas>)
  set set_delta(delta: NapiGPallas)
  set set_sg(sg: NapiGPallas)
}
export type NapiFqOpeningProof = WasmFqOpeningProof

export declare class WasmFqOracles {
  o: WasmFqRandomOracles
  p_eval0: NapiPastaFq
  p_eval1: NapiPastaFq
  digest_before_evaluations: NapiPastaFq
  constructor(o: NapiRandomOracles, pEval0: NapiPastaFq, pEval1: NapiPastaFq, openingPrechallenges: NapiFlatVector<NapiPastaFq>, digestBeforeEvaluations: NapiPastaFq)
  get opening_prechallenges(): NapiFlatVector<NapiPastaFq>
  set set_opening_prechallenges(x: NapiFlatVector<NapiPastaFq>)
}
export type NapiFqOracles = WasmFqOracles

export declare class WasmFqPolyComm {
  constructor(unshifted: NapiVector<NapiGPallas>, shifted?: NapiGPallas | undefined | null)
  get unshifted(): NapiVector<NapiGPallas>
  set set_unshifted(x: NapiVector<NapiGPallas>)
  get shifted(): NapiGPallas | null
  set set_shifted(value?: NapiGPallas | undefined | null)
}
export type NapiFqPolyComm = WasmFqPolyComm

export declare class WasmFqProverCommitments {
  constructor(wComm: NapiVector<WasmFqPolyComm>, zComm: WasmFqPolyComm, tComm: WasmFqPolyComm, lookup?: NapiLookupCommitments | undefined | null)
  get w_comm(): NapiVector<WasmFqPolyComm>
  get z_comm(): WasmFqPolyComm
  get t_comm(): WasmFqPolyComm
  get lookup(): NapiLookupCommitments | null
  set set_w_comm(x: NapiVector<WasmFqPolyComm>)
  set set_z_comm(x: WasmFqPolyComm)
  set set_t_comm(x: WasmFqPolyComm)
  set set_lookup(l?: NapiLookupCommitments | undefined | null)
}
export type NapiFqProverCommitments = WasmFqProverCommitments

export declare class WasmFqProverProof {
  /**
   * Drop the heavy proof contents by replacing them with a small
   * dummy. Rust memory behind napi objects is normally freed only
   * when the JS GC runs the wrapper's finalizer, which on wasm32
   * can be far too late (4 GiB ceiling, see o1js AGENT_LOG.md) —
   * callers that are done with a proof free it deterministically.
   */
  free(): void
  constructor(commitments: NapiProverCommitments, proof: NapiOpeningProof, evals: NapiProofEvaluations, ftEval1: NapiPastaFq, public: NapiFlatVector<NapiPastaFq>, prevChallengesScalars: NapiVecVecFq, prevChallengesComms: NapiVector<WasmFqPolyComm>)
  get commitments(): NapiProverCommitments
  get proof(): NapiOpeningProof
  get evals(): NapiProofEvaluations
  get ft_eval1(): NapiPastaFq
  get public_(): NapiFlatVector<NapiPastaFq>
  get prev_challenges_scalars(): NapiVecVecFq
  get prev_challenges_comms(): NapiVector<WasmFqPolyComm>
  set set_commitments(commitments: NapiProverCommitments)
  set set_proof(proof: NapiOpeningProof)
  set set_evals(evals: NapiProofEvaluations)
  set set_ft_eval1(ftEval1: NapiPastaFq)
  set set_public_(public: NapiFlatVector<NapiPastaFq>)
  set set_prev_challenges_scalars(prevChallengesScalars: NapiVecVecFq)
  set set_prev_challenges_comms(prevChallengesComms: NapiVector<WasmFqPolyComm>)
  serialize(): string
}
export type NapiFqProverProof = WasmFqProverProof

export declare class WasmFqRandomOracles {
  joint_combiner_chal?: NapiPastaFq
  joint_combiner?: NapiPastaFq
  beta: NapiPastaFq
  gamma: NapiPastaFq
  alpha_chal: NapiPastaFq
  alpha: NapiPastaFq
  zeta: NapiPastaFq
  v: NapiPastaFq
  u: NapiPastaFq
  zeta_chal: NapiPastaFq
  v_chal: NapiPastaFq
  u_chal: NapiPastaFq
  constructor(jointCombinerChal: NapiPastaFq | undefined | null, jointCombiner: NapiPastaFq | undefined | null, beta: NapiPastaFq, gamma: NapiPastaFq, alphaChal: NapiPastaFq, alpha: NapiPastaFq, zeta: NapiPastaFq, v: NapiPastaFq, u: NapiPastaFq, zetaChal: NapiPastaFq, vChal: NapiPastaFq, uChal: NapiPastaFq)
}
export type NapiFqRandomOracles = WasmFqRandomOracles

export declare class WasmFqSrs {
  serialize(): Uint8Array
  static deserialize(bytes: Uint8Array): WasmFqSrs
}
export type NapiFqSrs = WasmFqSrs

export declare class WasmPastaFpLookupTable {
  constructor(id: number, data: WasmVecVecFp)
  get id(): number
  set id(id: number)
  get data(): WasmVecVecFp
  set data(data: WasmVecVecFp)
}
export type NapiPastaFpLookupTable = WasmPastaFpLookupTable

export declare class WasmPastaFpPlonkIndex {

}

export declare class WasmPastaFpRuntimeTableCfg {
  constructor(id: number, firstColumn: Uint8Array)
  get id(): number
  set id(id: number)
  get first_column(): Uint8Array
}
export type NapiPastaFpRuntimeTableCfg = WasmPastaFpRuntimeTableCfg

export declare class WasmPastaFqLookupTable {
  constructor(id: number, data: WasmVecVecFq)
  get id(): number
  set id(id: number)
  get data(): WasmVecVecFq
  set data(data: WasmVecVecFq)
}
export type NapiPastaFqLookupTable = WasmPastaFqLookupTable

export declare class WasmPastaFqPlonkIndex {

}

export declare class WasmPastaFqRuntimeTableCfg {
  constructor(id: number, firstColumn: Uint8Array)
  get id(): number
  set id(id: number)
  get first_column(): Uint8Array
}
export type NapiPastaFqRuntimeTableCfg = WasmPastaFqRuntimeTableCfg

export declare class WasmVecVecFp {
  constructor(capacity: number)
  /**
   * Drop the contents (potentially tens of MB of witness data)
   * deterministically instead of waiting for the JS GC finalizer —
   * see o1js AGENT_LOG.md, wasm32 memory exhaustion.
   */
  free(): void
  push(vector: Uint8Array): void
  get(index: number): Uint8Array
  set(index: number, vector: Uint8Array): void
}
export type NapiVecVecFp = WasmVecVecFp

export declare class WasmVecVecFq {
  constructor(capacity: number)
  /**
   * Drop the contents (potentially tens of MB of witness data)
   * deterministically instead of waiting for the JS GC finalizer —
   * see o1js AGENT_LOG.md, wasm32 memory exhaustion.
   */
  free(): void
  push(vector: Uint8Array): void
  get(index: number): Uint8Array
  set(index: number, vector: Uint8Array): void
}
export type NapiVecVecFq = WasmVecVecFq

export const ARCH_NAME: string

export const BACKING: string

export declare function caml_fp_srs_add_lagrange_basis(srs: WasmFpSrs, log2Size: number): void

export declare function caml_fp_srs_b_poly_commitment(srs: WasmFpSrs, chals: Uint8Array): WasmFpPolyComm

export declare function caml_fp_srs_batch_accumulator_check(srs: WasmFpSrs, comms: NapiVector<NapiGVesta>, chals: Uint8Array): boolean

export declare function caml_fp_srs_batch_accumulator_generate(srs: WasmFpSrs, comms: number, chals: Uint8Array): NapiVector<NapiGVesta>

export declare function caml_fp_srs_commit_evaluations(srs: WasmFpSrs, domainSize: number, evals: Uint8Array): WasmFpPolyComm

export declare function caml_fp_srs_create(depth: number): WasmFpSrs

export declare function caml_fp_srs_create_parallel(depth: number): WasmFpSrs

export declare function caml_fp_srs_from_bytes(bytes: Uint8Array): NapiFpSrs

export declare function caml_fp_srs_from_raw_bytes(bytes: Uint8Array): WasmFpSrs

export declare function caml_fp_srs_get(srs: WasmFpSrs): Array<NapiGVesta>

export declare function caml_fp_srs_get_lagrange_basis(srs: WasmFpSrs, domainSize: number): NapiVector<WasmFpPolyComm>

export declare function caml_fp_srs_h(srs: WasmFpSrs): NapiGVesta

export declare function caml_fp_srs_lagrange_commitment(srs: WasmFpSrs, domainSize: number, i: number): WasmFpPolyComm

export declare function caml_fp_srs_lagrange_commitments_whole_domain_ptr(srs: WasmFpSrs, domainSize: number): NapiVector<WasmFpPolyComm>

export declare function caml_fp_srs_length(srs: WasmFpSrs): number

export declare function caml_fp_srs_maybe_lagrange_commitment(srs: WasmFpSrs, domainSize: number, i: number): WasmFpPolyComm | null

export declare function caml_fp_srs_read(offset: number | undefined | null, path: string): WasmFpSrs | null

export declare function caml_fp_srs_set(hAndGs: Array<NapiGVesta>): WasmFpSrs

export declare function caml_fp_srs_set_lagrange_basis(srs: WasmFpSrs, domainSize: number, inputBases: NapiVector<WasmFpPolyComm>): void

export declare function caml_fp_srs_to_bytes(srs: NapiFpSrs): Uint8Array

export declare function caml_fp_srs_to_raw_bytes(srs: WasmFpSrs): Uint8Array

export declare function caml_fp_srs_write(append: boolean | undefined | null, srs: WasmFpSrs, path: string): void

export declare function caml_fq_srs_add_lagrange_basis(srs: WasmFqSrs, log2Size: number): void

export declare function caml_fq_srs_b_poly_commitment(srs: WasmFqSrs, chals: Uint8Array): WasmFqPolyComm

export declare function caml_fq_srs_batch_accumulator_check(srs: WasmFqSrs, comms: NapiVector<NapiGPallas>, chals: Uint8Array): boolean

export declare function caml_fq_srs_batch_accumulator_generate(srs: WasmFqSrs, comms: number, chals: Uint8Array): NapiVector<NapiGPallas>

export declare function caml_fq_srs_commit_evaluations(srs: WasmFqSrs, domainSize: number, evals: Uint8Array): WasmFqPolyComm

export declare function caml_fq_srs_create(depth: number): WasmFqSrs

export declare function caml_fq_srs_create_parallel(depth: number): WasmFqSrs

export declare function caml_fq_srs_from_bytes(bytes: Uint8Array): NapiFqSrs

export declare function caml_fq_srs_from_raw_bytes(bytes: Uint8Array): WasmFqSrs

export declare function caml_fq_srs_get(srs: WasmFqSrs): Array<NapiGPallas>

export declare function caml_fq_srs_get_lagrange_basis(srs: WasmFqSrs, domainSize: number): NapiVector<WasmFqPolyComm>

export declare function caml_fq_srs_h(srs: WasmFqSrs): NapiGPallas

export declare function caml_fq_srs_lagrange_commitment(srs: WasmFqSrs, domainSize: number, i: number): WasmFqPolyComm

export declare function caml_fq_srs_lagrange_commitments_whole_domain_ptr(srs: WasmFqSrs, domainSize: number): NapiVector<WasmFqPolyComm>

export declare function caml_fq_srs_length(srs: WasmFqSrs): number

export declare function caml_fq_srs_maybe_lagrange_commitment(srs: WasmFqSrs, domainSize: number, i: number): WasmFqPolyComm | null

export declare function caml_fq_srs_read(offset: number | undefined | null, path: string): WasmFqSrs | null

export declare function caml_fq_srs_set(hAndGs: Array<NapiGPallas>): WasmFqSrs

export declare function caml_fq_srs_set_lagrange_basis(srs: WasmFqSrs, domainSize: number, inputBases: NapiVector<WasmFqPolyComm>): void

export declare function caml_fq_srs_to_bytes(srs: NapiFqSrs): Uint8Array

export declare function caml_fq_srs_to_raw_bytes(srs: WasmFqSrs): Uint8Array

export declare function caml_fq_srs_write(append: boolean | undefined | null, srs: WasmFqSrs, path: string): void

export declare function caml_pallas_affine_one(): WasmGPallas

export declare function caml_pasta_fp_plonk_circuit_serialize(publicInputSize: number, vector: WasmFpGateVector): string

export declare function caml_pasta_fp_plonk_gate_vector_add(vector: WasmFpGateVector, typ: number, wires: Int32Array, coeffs: Uint8Array): void

export declare function caml_pasta_fp_plonk_gate_vector_create(): WasmFpGateVector

export declare function caml_pasta_fp_plonk_gate_vector_digest(publicInputSize: number, vector: WasmFpGateVector): Uint8Array

export declare function caml_pasta_fp_plonk_gate_vector_from_bytes(bytes: Uint8Array): WasmFpGateVector

export declare function caml_pasta_fp_plonk_gate_vector_get(vector: WasmFpGateVector, index: number): WasmFpGate

export declare function caml_pasta_fp_plonk_gate_vector_len(vector: WasmFpGateVector): number

export declare function caml_pasta_fp_plonk_gate_vector_to_bytes(vector: WasmFpGateVector): Uint8Array

export declare function caml_pasta_fp_plonk_gate_vector_wrap(vector: WasmFpGateVector, target: NapiWire, head: NapiWire): void

export declare function caml_pasta_fp_plonk_index_create(gates: WasmFpGateVector, public: number, lookupTables: Array<JsLookupTableFp>, runtimeTableCfgs: Array<JsRuntimeTableCfgFp>, prevChallenges: number, srs: WasmFpSrs, lazyMode: boolean): ExternalObject<WasmPastaFpPlonkIndex>

export declare function caml_pasta_fp_plonk_index_decode(bytes: Uint8Array, srs: WasmFpSrs): ExternalObject<WasmPastaFpPlonkIndex>

export declare function caml_pasta_fp_plonk_index_domain_d1_size(index: ExternalObject<WasmPastaFpPlonkIndex>): number

export declare function caml_pasta_fp_plonk_index_domain_d4_size(index: ExternalObject<WasmPastaFpPlonkIndex>): number

export declare function caml_pasta_fp_plonk_index_encode(index: ExternalObject<WasmPastaFpPlonkIndex>): Uint8Array

export declare function caml_pasta_fp_plonk_index_max_degree(index: ExternalObject<WasmPastaFpPlonkIndex>): number

export declare function caml_pasta_fp_plonk_index_public_inputs(index: ExternalObject<WasmPastaFpPlonkIndex>): number

export declare function caml_pasta_fp_plonk_index_read(offset: number | undefined | null, srs: WasmFpSrs, path: string): ExternalObject<WasmPastaFpPlonkIndex>

export declare function caml_pasta_fp_plonk_index_write(append: boolean | undefined | null, index: ExternalObject<WasmPastaFpPlonkIndex>, path: string): void

export declare function caml_pasta_fp_plonk_proof_batch_verify(indexes: NapiVector<WasmFpPlonkVerifierIndex>, proofs: NapiVector<NapiProofF>): boolean

export declare function caml_pasta_fp_plonk_proof_create(index: ExternalObject<NapiPastaFpPlonkIndex>, witness: NapiVecVecFp, runtimeTables: NapiVector<NapiFpRuntimeTable>, prevChallenges: NapiFlatVector<NapiPastaFp>, prevSgs: NapiVector<NapiGVesta>): NapiProofF

export declare function caml_pasta_fp_plonk_proof_deep_copy(x: NapiProofF): NapiProofF

export declare function caml_pasta_fp_plonk_proof_dummy(): NapiProofF

export declare function caml_pasta_fp_plonk_proof_verify(index: WasmFpPlonkVerifierIndex, proof: NapiProofF): boolean

export declare function caml_pasta_fp_plonk_verifier_index_create(index: ExternalObject<NapiPastaFpPlonkIndex>): NapiPlonkVerifierIndex

export declare function caml_pasta_fp_plonk_verifier_index_deep_copy(x: NapiPlonkVerifierIndex): NapiPlonkVerifierIndex

export declare function caml_pasta_fp_plonk_verifier_index_deserialize(srs: NapiFpSrs, index: string): NapiPlonkVerifierIndex

export declare function caml_pasta_fp_plonk_verifier_index_dummy(): NapiPlonkVerifierIndex

export declare function caml_pasta_fp_plonk_verifier_index_read(offset: number | undefined | null, srs: NapiFpSrs, path: string): NapiPlonkVerifierIndex

export declare function caml_pasta_fp_plonk_verifier_index_serialize(index: NapiPlonkVerifierIndex): string

export declare function caml_pasta_fp_plonk_verifier_index_shifts(log2Size: number): NapiShifts

export declare function caml_pasta_fp_plonk_verifier_index_write(append: boolean | undefined | null, index: NapiPlonkVerifierIndex, path: string): void

export declare function caml_pasta_fp_poseidon_block_cipher(state: Uint8Array): Uint8Array

export declare function caml_pasta_fq_plonk_circuit_serialize(publicInputSize: number, vector: WasmFqGateVector): string

export declare function caml_pasta_fq_plonk_gate_vector_add(vector: WasmFqGateVector, typ: number, wires: Int32Array, coeffs: Uint8Array): void

export declare function caml_pasta_fq_plonk_gate_vector_create(): WasmFqGateVector

export declare function caml_pasta_fq_plonk_gate_vector_digest(publicInputSize: number, vector: WasmFqGateVector): Uint8Array

export declare function caml_pasta_fq_plonk_gate_vector_from_bytes(bytes: Uint8Array): WasmFqGateVector

export declare function caml_pasta_fq_plonk_gate_vector_get(vector: WasmFqGateVector, index: number): WasmFqGate

export declare function caml_pasta_fq_plonk_gate_vector_len(vector: WasmFqGateVector): number

export declare function caml_pasta_fq_plonk_gate_vector_to_bytes(vector: WasmFqGateVector): Uint8Array

export declare function caml_pasta_fq_plonk_gate_vector_wrap(vector: WasmFqGateVector, target: NapiWire, head: NapiWire): void

export declare function caml_pasta_fq_plonk_index_create(gates: WasmFqGateVector, public: number, lookupTables: Array<JsLookupTableFq>, runtimeTableCfgs: Array<JsRuntimeTableCfgFq>, prevChallenges: number, srs: WasmFqSrs, lazyMode: boolean): ExternalObject<WasmPastaFqPlonkIndex>

export declare function caml_pasta_fq_plonk_index_decode(bytes: Uint8Array, srs: WasmFqSrs): ExternalObject<WasmPastaFqPlonkIndex>

export declare function caml_pasta_fq_plonk_index_domain_d1_size(index: ExternalObject<WasmPastaFqPlonkIndex>): number

export declare function caml_pasta_fq_plonk_index_domain_d4_size(index: ExternalObject<WasmPastaFqPlonkIndex>): number

export declare function caml_pasta_fq_plonk_index_domain_d8_size(index: ExternalObject<WasmPastaFqPlonkIndex>): number

export declare function caml_pasta_fq_plonk_index_encode(index: ExternalObject<WasmPastaFqPlonkIndex>): Uint8Array

export declare function caml_pasta_fq_plonk_index_max_degree(index: ExternalObject<WasmPastaFqPlonkIndex>): number

export declare function caml_pasta_fq_plonk_index_public_inputs(index: ExternalObject<WasmPastaFqPlonkIndex>): number

export declare function caml_pasta_fq_plonk_index_read(offset: number | undefined | null, srs: WasmFqSrs, path: string): ExternalObject<WasmPastaFqPlonkIndex>

export declare function caml_pasta_fq_plonk_index_write(append: boolean | undefined | null, index: ExternalObject<WasmPastaFqPlonkIndex>, path: string): void

export declare function caml_pasta_fq_plonk_proof_batch_verify(indexes: NapiVector<WasmFqPlonkVerifierIndex>, proofs: NapiVector<NapiProofF>): boolean

export declare function caml_pasta_fq_plonk_proof_create(index: ExternalObject<NapiPastaFqPlonkIndex>, witness: NapiVecVecFq, runtimeTables: NapiVector<NapiFqRuntimeTable>, prevChallenges: NapiFlatVector<NapiPastaFq>, prevSgs: NapiVector<NapiGPallas>): NapiProofF

export declare function caml_pasta_fq_plonk_proof_deep_copy(x: NapiProofF): NapiProofF

export declare function caml_pasta_fq_plonk_proof_dummy(): NapiProofF

export declare function caml_pasta_fq_plonk_proof_verify(index: WasmFqPlonkVerifierIndex, proof: NapiProofF): boolean

export declare function caml_pasta_fq_plonk_verifier_index_create(index: ExternalObject<NapiPastaFqPlonkIndex>): NapiPlonkVerifierIndex

export declare function caml_pasta_fq_plonk_verifier_index_deep_copy(x: NapiPlonkVerifierIndex): NapiPlonkVerifierIndex

export declare function caml_pasta_fq_plonk_verifier_index_deserialize(srs: NapiFqSrs, index: string): NapiPlonkVerifierIndex

export declare function caml_pasta_fq_plonk_verifier_index_dummy(): NapiPlonkVerifierIndex

export declare function caml_pasta_fq_plonk_verifier_index_read(offset: number | undefined | null, srs: NapiFqSrs, path: string): NapiPlonkVerifierIndex

export declare function caml_pasta_fq_plonk_verifier_index_serialize(index: NapiPlonkVerifierIndex): string

export declare function caml_pasta_fq_plonk_verifier_index_shifts(log2Size: number): NapiShifts

export declare function caml_pasta_fq_plonk_verifier_index_write(append: boolean | undefined | null, index: NapiPlonkVerifierIndex, path: string): void

export declare function caml_pasta_fq_poseidon_block_cipher(state: Uint8Array): Uint8Array

export declare function caml_vesta_affine_one(): WasmGVesta

export declare function camlPastaFpPlonkGateVectorFromBytesExternal(bytes: Uint8Array): ExternalObject<WasmFpGateVector>

export declare function camlPastaFqPlonkGateVectorFromBytesExternal(bytes: Uint8Array): ExternalObject<WasmFqGateVector>

export declare function camlRayonInitSingleThreaded(): boolean

export declare function camlRayonSpawnPool(numThreads: number): boolean

export declare function camlRayonStartedThreads(): number

export declare function fp_oracles_create(lgrComm: NapiVector<WasmPolyComm>, index: WasmPlonkVerifierIndex, proof: WasmProverProof): WasmFpOracles

export declare function fp_oracles_deep_copy(x: WasmProverProof): WasmProverProof

export declare function fp_oracles_dummy(): WasmFpOracles

export declare function fq_oracles_create(lgrComm: NapiVector<WasmPolyComm>, index: WasmPlonkVerifierIndex, proof: WasmProverProof): WasmFqOracles

export declare function fq_oracles_deep_copy(x: WasmProverProof): WasmProverProof

export declare function fq_oracles_dummy(): WasmFqOracles

export declare function getNativeCalls(): bigint

export interface JsLookupTableFp {
  id: number
  data: Array<Uint8Array>
}

export interface JsLookupTableFq {
  id: number
  data: Array<Uint8Array>
}

export interface JsRuntimeTableCfgFp {
  id: number
  firstColumn: Uint8Array
}

export interface JsRuntimeTableCfgFq {
  id: number
  firstColumn: Uint8Array
}

export interface NapiWire {
  row: number
  col: number
}

export const OS_NAME: string

export declare function pasta_fp_plonk_index_domain_d8_size(index: ExternalObject<WasmPastaFpPlonkIndex>): number

export declare function prover_index_fp_deserialize(bytes: Uint8Array): ExternalObject<WasmPastaFpPlonkIndex>

export declare function prover_index_fp_serialize(index: ExternalObject<WasmPastaFpPlonkIndex>): Uint8Array

export declare function prover_index_fq_deserialize(bytes: Uint8Array): ExternalObject<WasmPastaFqPlonkIndex>

export declare function prover_index_fq_serialize(index: ExternalObject<WasmPastaFqPlonkIndex>): Uint8Array

export declare function prover_to_json(proverIndex: ExternalObject<WasmPastaFpPlonkIndex>): string

export interface WasmFeatureFlags {
  range_check0: boolean
  range_check1: boolean
  foreign_field_add: boolean
  foreign_field_mul: boolean
  xor: boolean
  rot: boolean
  lookup: boolean
  runtime_tables: boolean
}

export interface WasmFpDomain {
  log_size_of_group: number
  group_gen: NapiPastaFp
}

export interface WasmFpGate {
  typ: number
  wires: WasmGateWires
  coeffs: Array<number>
}

export interface WasmFpLookupSelectors {
  xor?: NapiPolyComm
  lookup?: NapiPolyComm
  range_check?: NapiPolyComm
  ffmul?: NapiPolyComm
}

export interface WasmFpLookupVerifierIndex {
  joint_lookup_used: boolean
  lookup_table: NapiVector<NapiPolyComm>
  lookup_selectors: NapiLookupSelectors
  table_ids?: NapiPolyComm
  lookup_info: NapiLookupInfo
  runtime_tables_selector?: NapiPolyComm
}

export interface WasmFpPlonkVerificationEvals {
  sigma_comm: NapiVector<NapiPolyComm>
  coefficients_comm: NapiVector<NapiPolyComm>
  generic_comm: NapiPolyComm
  psm_comm: NapiPolyComm
  complete_add_comm: NapiPolyComm
  mul_comm: NapiPolyComm
  emul_comm: NapiPolyComm
  endomul_scalar_comm: NapiPolyComm
  xor_comm?: NapiPolyComm
  range_check0_comm?: NapiPolyComm
  range_check1_comm?: NapiPolyComm
  foreign_field_add_comm?: NapiPolyComm
  foreign_field_mul_comm?: NapiPolyComm
  rot_comm?: NapiPolyComm
}

export interface WasmFpPlonkVerifierIndex {
  domain: NapiDomain
  max_poly_size: number
  public_: number
  prev_challenges: number
  srs: NapiFpSrs
  evals: NapiPlonkVerificationEvals
  shifts: NapiShifts
  lookup_index?: NapiLookupVerifierIndex
  zk_rows: number
}

export interface WasmFpPointEvaluations {
  zeta: NapiVector<NapiPastaFp>
  zetaOmega: NapiVector<NapiPastaFp>
}

export interface WasmFpProofEvaluationsObject {
  public?: NapiPointEvaluations
  w: NapiVector<NapiPointEvaluations>
  z: NapiPointEvaluations
  s: NapiVector<NapiPointEvaluations>
  coefficients: NapiVector<NapiPointEvaluations>
  genericSelector: NapiPointEvaluations
  poseidonSelector: NapiPointEvaluations
  completeAddSelector: NapiPointEvaluations
  mulSelector: NapiPointEvaluations
  emulSelector: NapiPointEvaluations
  endomulScalarSelector: NapiPointEvaluations
  rangeCheck0Selector?: NapiPointEvaluations
  rangeCheck1Selector?: NapiPointEvaluations
  foreignFieldAddSelector?: NapiPointEvaluations
  foreignFieldMulSelector?: NapiPointEvaluations
  xorSelector?: NapiPointEvaluations
  rotSelector?: NapiPointEvaluations
  lookupAggregation?: NapiPointEvaluations
  lookupTable?: NapiPointEvaluations
  lookupSorted: NapiVector<NapiPointEvaluations | undefined | null>
  runtimeLookupTable?: NapiPointEvaluations
  runtimeLookupTableSelector?: NapiPointEvaluations
  xorLookupSelector?: NapiPointEvaluations
  lookupGateLookupSelector?: NapiPointEvaluations
  rangeCheckLookupSelector?: NapiPointEvaluations
  foreignFieldMulLookupSelector?: NapiPointEvaluations
}

export interface WasmFpRuntimeTable {
  id: number
  data: NapiFlatVector<NapiPastaFp>
}

export interface WasmFpShifts {
  s0: NapiPastaFp
  s1: NapiPastaFp
  s2: NapiPastaFp
  s3: NapiPastaFp
  s4: NapiPastaFp
  s5: NapiPastaFp
  s6: NapiPastaFp
}

export interface WasmFqDomain {
  log_size_of_group: number
  group_gen: NapiPastaFq
}

export interface WasmFqGate {
  typ: number
  wires: WasmGateWires
  coeffs: Array<number>
}

export interface WasmFqLookupSelectors {
  xor?: NapiPolyComm
  lookup?: NapiPolyComm
  range_check?: NapiPolyComm
  ffmul?: NapiPolyComm
}

export interface WasmFqLookupVerifierIndex {
  joint_lookup_used: boolean
  lookup_table: NapiVector<NapiPolyComm>
  lookup_selectors: NapiLookupSelectors
  table_ids?: NapiPolyComm
  lookup_info: NapiLookupInfo
  runtime_tables_selector?: NapiPolyComm
}

export interface WasmFqPlonkVerificationEvals {
  sigma_comm: NapiVector<NapiPolyComm>
  coefficients_comm: NapiVector<NapiPolyComm>
  generic_comm: NapiPolyComm
  psm_comm: NapiPolyComm
  complete_add_comm: NapiPolyComm
  mul_comm: NapiPolyComm
  emul_comm: NapiPolyComm
  endomul_scalar_comm: NapiPolyComm
  xor_comm?: NapiPolyComm
  range_check0_comm?: NapiPolyComm
  range_check1_comm?: NapiPolyComm
  foreign_field_add_comm?: NapiPolyComm
  foreign_field_mul_comm?: NapiPolyComm
  rot_comm?: NapiPolyComm
}

export interface WasmFqPlonkVerifierIndex {
  domain: NapiDomain
  max_poly_size: number
  public_: number
  prev_challenges: number
  srs: NapiFqSrs
  evals: NapiPlonkVerificationEvals
  shifts: NapiShifts
  lookup_index?: NapiLookupVerifierIndex
  zk_rows: number
}

export interface WasmFqPointEvaluations {
  zeta: NapiVector<NapiPastaFq>
  zetaOmega: NapiVector<NapiPastaFq>
}

export interface WasmFqProofEvaluationsObject {
  public?: NapiPointEvaluations
  w: NapiVector<NapiPointEvaluations>
  z: NapiPointEvaluations
  s: NapiVector<NapiPointEvaluations>
  coefficients: NapiVector<NapiPointEvaluations>
  genericSelector: NapiPointEvaluations
  poseidonSelector: NapiPointEvaluations
  completeAddSelector: NapiPointEvaluations
  mulSelector: NapiPointEvaluations
  emulSelector: NapiPointEvaluations
  endomulScalarSelector: NapiPointEvaluations
  rangeCheck0Selector?: NapiPointEvaluations
  rangeCheck1Selector?: NapiPointEvaluations
  foreignFieldAddSelector?: NapiPointEvaluations
  foreignFieldMulSelector?: NapiPointEvaluations
  xorSelector?: NapiPointEvaluations
  rotSelector?: NapiPointEvaluations
  lookupAggregation?: NapiPointEvaluations
  lookupTable?: NapiPointEvaluations
  lookupSorted: NapiVector<NapiPointEvaluations | undefined | null>
  runtimeLookupTable?: NapiPointEvaluations
  runtimeLookupTableSelector?: NapiPointEvaluations
  xorLookupSelector?: NapiPointEvaluations
  lookupGateLookupSelector?: NapiPointEvaluations
  rangeCheckLookupSelector?: NapiPointEvaluations
  foreignFieldMulLookupSelector?: NapiPointEvaluations
}

export interface WasmFqRuntimeTable {
  id: number
  data: NapiFlatVector<NapiPastaFq>
}

export interface WasmFqShifts {
  s0: NapiPastaFq
  s1: NapiPastaFq
  s2: NapiPastaFq
  s3: NapiPastaFq
  s4: NapiPastaFq
  s5: NapiPastaFq
  s6: NapiPastaFq
}

export interface WasmGateWires {
  w0: NapiWire
  w1: NapiWire
  w2: NapiWire
  w3: NapiWire
  w4: NapiWire
  w5: NapiWire
  w6: NapiWire
}

export interface WasmGPallas {
  x: NapiPastaFp
  y: NapiPastaFp
  infinity: boolean
}

export interface WasmGVesta {
  x: NapiPastaFq
  y: NapiPastaFq
  infinity: boolean
}

export interface WasmLookupFeatures {
  patterns: WasmLookupPatterns
  joint_lookup_used: boolean
  uses_runtime_tables: boolean
}

export interface WasmLookupInfo {
  max_per_row: number
  max_joint_size: number
  features: WasmLookupFeatures
}

export interface WasmLookupPatterns {
  xor: boolean
  lookup: boolean
  range_check: boolean
  foreign_field_mul: boolean
}
