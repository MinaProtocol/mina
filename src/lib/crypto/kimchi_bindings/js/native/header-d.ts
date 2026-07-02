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
