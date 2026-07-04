import {
  createOnMessage as __wasmCreateOnMessageForFsProxy,
  getDefaultContext as __emnapiGetDefaultContext,
  instantiateNapiModuleSync as __emnapiInstantiateNapiModuleSync,
  WASI as __WASI,
} from '@napi-rs/wasm-runtime'



const __wasi = new __WASI({
  version: 'preview1',
})

const __wasmUrl = new URL('./kimchi_napi.wasm32-wasi.wasm', import.meta.url).href
const __emnapiContext = __emnapiGetDefaultContext()


const __sharedMemory = new WebAssembly.Memory({
  initial: 1024,
  maximum: 65536,
  shared: true,
})

const __wasmFile = await fetch(__wasmUrl).then((res) => res.arrayBuffer())

const {
  instance: __napiInstance,
  module: __wasiModule,
  napiModule: __napiModule,
} = __emnapiInstantiateNapiModuleSync(__wasmFile, {
  context: __emnapiContext,
  asyncWorkPoolSize: 4,
  wasi: __wasi,
  onCreateWorker() {
    const worker = new Worker(new URL('./wasi-worker-browser.mjs', import.meta.url), {
      type: 'module',
    })

    return worker
  },
  overwriteImports(importObject) {
    importObject.env = {
      ...importObject.env,
      ...importObject.napi,
      ...importObject.emnapi,
      memory: __sharedMemory,
    }
    return importObject
  },
  beforeInit({ instance }) {
    for (const name of Object.keys(instance.exports)) {
      if (name.startsWith('__napi_register__')) {
        instance.exports[name]()
      }
    }
  },
})
export default __napiModule.exports
export const WasmFpGateVector = __napiModule.exports.WasmFpGateVector
export const NapiFpGateVector = __napiModule.exports.NapiFpGateVector
export const WasmFpLookupCommitments = __napiModule.exports.WasmFpLookupCommitments
export const NapiFpLookupCommitments = __napiModule.exports.NapiFpLookupCommitments
export const WasmFpOpeningProof = __napiModule.exports.WasmFpOpeningProof
export const NapiFpOpeningProof = __napiModule.exports.NapiFpOpeningProof
export const WasmFpOracles = __napiModule.exports.WasmFpOracles
export const NapiFpOracles = __napiModule.exports.NapiFpOracles
export const WasmFpPolyComm = __napiModule.exports.WasmFpPolyComm
export const NapiFpPolyComm = __napiModule.exports.NapiFpPolyComm
export const WasmFpProverCommitments = __napiModule.exports.WasmFpProverCommitments
export const NapiFpProverCommitments = __napiModule.exports.NapiFpProverCommitments
export const WasmFpProverProof = __napiModule.exports.WasmFpProverProof
export const NapiFpProverProof = __napiModule.exports.NapiFpProverProof
export const WasmFpRandomOracles = __napiModule.exports.WasmFpRandomOracles
export const NapiFpRandomOracles = __napiModule.exports.NapiFpRandomOracles
export const WasmFpSrs = __napiModule.exports.WasmFpSrs
export const NapiFpSrs = __napiModule.exports.NapiFpSrs
export const WasmFqGateVector = __napiModule.exports.WasmFqGateVector
export const NapiFqGateVector = __napiModule.exports.NapiFqGateVector
export const WasmFqLookupCommitments = __napiModule.exports.WasmFqLookupCommitments
export const NapiFqLookupCommitments = __napiModule.exports.NapiFqLookupCommitments
export const WasmFqOpeningProof = __napiModule.exports.WasmFqOpeningProof
export const NapiFqOpeningProof = __napiModule.exports.NapiFqOpeningProof
export const WasmFqOracles = __napiModule.exports.WasmFqOracles
export const NapiFqOracles = __napiModule.exports.NapiFqOracles
export const WasmFqPolyComm = __napiModule.exports.WasmFqPolyComm
export const NapiFqPolyComm = __napiModule.exports.NapiFqPolyComm
export const WasmFqProverCommitments = __napiModule.exports.WasmFqProverCommitments
export const NapiFqProverCommitments = __napiModule.exports.NapiFqProverCommitments
export const WasmFqProverProof = __napiModule.exports.WasmFqProverProof
export const NapiFqProverProof = __napiModule.exports.NapiFqProverProof
export const WasmFqRandomOracles = __napiModule.exports.WasmFqRandomOracles
export const NapiFqRandomOracles = __napiModule.exports.NapiFqRandomOracles
export const WasmFqSrs = __napiModule.exports.WasmFqSrs
export const NapiFqSrs = __napiModule.exports.NapiFqSrs
export const WasmPastaFpLookupTable = __napiModule.exports.WasmPastaFpLookupTable
export const NapiPastaFpLookupTable = __napiModule.exports.NapiPastaFpLookupTable
export const WasmPastaFpPlonkIndex = __napiModule.exports.WasmPastaFpPlonkIndex
export const WasmPastaFpRuntimeTableCfg = __napiModule.exports.WasmPastaFpRuntimeTableCfg
export const NapiPastaFpRuntimeTableCfg = __napiModule.exports.NapiPastaFpRuntimeTableCfg
export const WasmPastaFqLookupTable = __napiModule.exports.WasmPastaFqLookupTable
export const NapiPastaFqLookupTable = __napiModule.exports.NapiPastaFqLookupTable
export const WasmPastaFqPlonkIndex = __napiModule.exports.WasmPastaFqPlonkIndex
export const WasmPastaFqRuntimeTableCfg = __napiModule.exports.WasmPastaFqRuntimeTableCfg
export const NapiPastaFqRuntimeTableCfg = __napiModule.exports.NapiPastaFqRuntimeTableCfg
export const WasmVecVecFp = __napiModule.exports.WasmVecVecFp
export const NapiVecVecFp = __napiModule.exports.NapiVecVecFp
export const WasmVecVecFq = __napiModule.exports.WasmVecVecFq
export const NapiVecVecFq = __napiModule.exports.NapiVecVecFq
export const ARCH_NAME = __napiModule.exports.ARCH_NAME
export const BACKING = __napiModule.exports.BACKING
export const caml_fp_srs_add_lagrange_basis = __napiModule.exports.caml_fp_srs_add_lagrange_basis
export const caml_fp_srs_b_poly_commitment = __napiModule.exports.caml_fp_srs_b_poly_commitment
export const caml_fp_srs_batch_accumulator_check = __napiModule.exports.caml_fp_srs_batch_accumulator_check
export const caml_fp_srs_batch_accumulator_generate = __napiModule.exports.caml_fp_srs_batch_accumulator_generate
export const caml_fp_srs_commit_evaluations = __napiModule.exports.caml_fp_srs_commit_evaluations
export const caml_fp_srs_create = __napiModule.exports.caml_fp_srs_create
export const caml_fp_srs_create_parallel = __napiModule.exports.caml_fp_srs_create_parallel
export const caml_fp_srs_from_bytes = __napiModule.exports.caml_fp_srs_from_bytes
export const caml_fp_srs_from_raw_bytes = __napiModule.exports.caml_fp_srs_from_raw_bytes
export const caml_fp_srs_get = __napiModule.exports.caml_fp_srs_get
export const caml_fp_srs_get_lagrange_basis = __napiModule.exports.caml_fp_srs_get_lagrange_basis
export const caml_fp_srs_h = __napiModule.exports.caml_fp_srs_h
export const caml_fp_srs_lagrange_commitment = __napiModule.exports.caml_fp_srs_lagrange_commitment
export const caml_fp_srs_lagrange_commitments_whole_domain_ptr = __napiModule.exports.caml_fp_srs_lagrange_commitments_whole_domain_ptr
export const caml_fp_srs_length = __napiModule.exports.caml_fp_srs_length
export const caml_fp_srs_maybe_lagrange_commitment = __napiModule.exports.caml_fp_srs_maybe_lagrange_commitment
export const caml_fp_srs_read = __napiModule.exports.caml_fp_srs_read
export const caml_fp_srs_set = __napiModule.exports.caml_fp_srs_set
export const caml_fp_srs_set_lagrange_basis = __napiModule.exports.caml_fp_srs_set_lagrange_basis
export const caml_fp_srs_to_bytes = __napiModule.exports.caml_fp_srs_to_bytes
export const caml_fp_srs_to_raw_bytes = __napiModule.exports.caml_fp_srs_to_raw_bytes
export const caml_fp_srs_write = __napiModule.exports.caml_fp_srs_write
export const caml_fq_srs_add_lagrange_basis = __napiModule.exports.caml_fq_srs_add_lagrange_basis
export const caml_fq_srs_b_poly_commitment = __napiModule.exports.caml_fq_srs_b_poly_commitment
export const caml_fq_srs_batch_accumulator_check = __napiModule.exports.caml_fq_srs_batch_accumulator_check
export const caml_fq_srs_batch_accumulator_generate = __napiModule.exports.caml_fq_srs_batch_accumulator_generate
export const caml_fq_srs_commit_evaluations = __napiModule.exports.caml_fq_srs_commit_evaluations
export const caml_fq_srs_create = __napiModule.exports.caml_fq_srs_create
export const caml_fq_srs_create_parallel = __napiModule.exports.caml_fq_srs_create_parallel
export const caml_fq_srs_from_bytes = __napiModule.exports.caml_fq_srs_from_bytes
export const caml_fq_srs_from_raw_bytes = __napiModule.exports.caml_fq_srs_from_raw_bytes
export const caml_fq_srs_get = __napiModule.exports.caml_fq_srs_get
export const caml_fq_srs_get_lagrange_basis = __napiModule.exports.caml_fq_srs_get_lagrange_basis
export const caml_fq_srs_h = __napiModule.exports.caml_fq_srs_h
export const caml_fq_srs_lagrange_commitment = __napiModule.exports.caml_fq_srs_lagrange_commitment
export const caml_fq_srs_lagrange_commitments_whole_domain_ptr = __napiModule.exports.caml_fq_srs_lagrange_commitments_whole_domain_ptr
export const caml_fq_srs_length = __napiModule.exports.caml_fq_srs_length
export const caml_fq_srs_maybe_lagrange_commitment = __napiModule.exports.caml_fq_srs_maybe_lagrange_commitment
export const caml_fq_srs_read = __napiModule.exports.caml_fq_srs_read
export const caml_fq_srs_set = __napiModule.exports.caml_fq_srs_set
export const caml_fq_srs_set_lagrange_basis = __napiModule.exports.caml_fq_srs_set_lagrange_basis
export const caml_fq_srs_to_bytes = __napiModule.exports.caml_fq_srs_to_bytes
export const caml_fq_srs_to_raw_bytes = __napiModule.exports.caml_fq_srs_to_raw_bytes
export const caml_fq_srs_write = __napiModule.exports.caml_fq_srs_write
export const caml_pallas_affine_one = __napiModule.exports.caml_pallas_affine_one
export const caml_pasta_fp_plonk_circuit_serialize = __napiModule.exports.caml_pasta_fp_plonk_circuit_serialize
export const caml_pasta_fp_plonk_gate_vector_add = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_add
export const caml_pasta_fp_plonk_gate_vector_create = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_create
export const caml_pasta_fp_plonk_gate_vector_digest = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_digest
export const caml_pasta_fp_plonk_gate_vector_from_bytes = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_from_bytes
export const caml_pasta_fp_plonk_gate_vector_get = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_get
export const caml_pasta_fp_plonk_gate_vector_len = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_len
export const caml_pasta_fp_plonk_gate_vector_to_bytes = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_to_bytes
export const caml_pasta_fp_plonk_gate_vector_wrap = __napiModule.exports.caml_pasta_fp_plonk_gate_vector_wrap
export const caml_pasta_fp_plonk_index_create = __napiModule.exports.caml_pasta_fp_plonk_index_create
export const caml_pasta_fp_plonk_index_decode = __napiModule.exports.caml_pasta_fp_plonk_index_decode
export const caml_pasta_fp_plonk_index_domain_d1_size = __napiModule.exports.caml_pasta_fp_plonk_index_domain_d1_size
export const caml_pasta_fp_plonk_index_domain_d4_size = __napiModule.exports.caml_pasta_fp_plonk_index_domain_d4_size
export const caml_pasta_fp_plonk_index_encode = __napiModule.exports.caml_pasta_fp_plonk_index_encode
export const caml_pasta_fp_plonk_index_max_degree = __napiModule.exports.caml_pasta_fp_plonk_index_max_degree
export const caml_pasta_fp_plonk_index_public_inputs = __napiModule.exports.caml_pasta_fp_plonk_index_public_inputs
export const caml_pasta_fp_plonk_index_read = __napiModule.exports.caml_pasta_fp_plonk_index_read
export const caml_pasta_fp_plonk_index_write = __napiModule.exports.caml_pasta_fp_plonk_index_write
export const caml_pasta_fp_plonk_proof_batch_verify = __napiModule.exports.caml_pasta_fp_plonk_proof_batch_verify
export const caml_pasta_fp_plonk_proof_create = __napiModule.exports.caml_pasta_fp_plonk_proof_create
export const caml_pasta_fp_plonk_proof_deep_copy = __napiModule.exports.caml_pasta_fp_plonk_proof_deep_copy
export const caml_pasta_fp_plonk_proof_dummy = __napiModule.exports.caml_pasta_fp_plonk_proof_dummy
export const caml_pasta_fp_plonk_proof_verify = __napiModule.exports.caml_pasta_fp_plonk_proof_verify
export const caml_pasta_fp_plonk_verifier_index_create = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_create
export const caml_pasta_fp_plonk_verifier_index_deep_copy = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_deep_copy
export const caml_pasta_fp_plonk_verifier_index_deserialize = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_deserialize
export const caml_pasta_fp_plonk_verifier_index_dummy = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_dummy
export const caml_pasta_fp_plonk_verifier_index_read = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_read
export const caml_pasta_fp_plonk_verifier_index_serialize = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_serialize
export const caml_pasta_fp_plonk_verifier_index_shifts = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_shifts
export const caml_pasta_fp_plonk_verifier_index_write = __napiModule.exports.caml_pasta_fp_plonk_verifier_index_write
export const caml_pasta_fp_poseidon_block_cipher = __napiModule.exports.caml_pasta_fp_poseidon_block_cipher
export const caml_pasta_fq_plonk_circuit_serialize = __napiModule.exports.caml_pasta_fq_plonk_circuit_serialize
export const caml_pasta_fq_plonk_gate_vector_add = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_add
export const caml_pasta_fq_plonk_gate_vector_create = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_create
export const caml_pasta_fq_plonk_gate_vector_digest = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_digest
export const caml_pasta_fq_plonk_gate_vector_from_bytes = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_from_bytes
export const caml_pasta_fq_plonk_gate_vector_get = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_get
export const caml_pasta_fq_plonk_gate_vector_len = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_len
export const caml_pasta_fq_plonk_gate_vector_to_bytes = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_to_bytes
export const caml_pasta_fq_plonk_gate_vector_wrap = __napiModule.exports.caml_pasta_fq_plonk_gate_vector_wrap
export const caml_pasta_fq_plonk_index_create = __napiModule.exports.caml_pasta_fq_plonk_index_create
export const caml_pasta_fq_plonk_index_decode = __napiModule.exports.caml_pasta_fq_plonk_index_decode
export const caml_pasta_fq_plonk_index_domain_d1_size = __napiModule.exports.caml_pasta_fq_plonk_index_domain_d1_size
export const caml_pasta_fq_plonk_index_domain_d4_size = __napiModule.exports.caml_pasta_fq_plonk_index_domain_d4_size
export const caml_pasta_fq_plonk_index_domain_d8_size = __napiModule.exports.caml_pasta_fq_plonk_index_domain_d8_size
export const caml_pasta_fq_plonk_index_encode = __napiModule.exports.caml_pasta_fq_plonk_index_encode
export const caml_pasta_fq_plonk_index_max_degree = __napiModule.exports.caml_pasta_fq_plonk_index_max_degree
export const caml_pasta_fq_plonk_index_public_inputs = __napiModule.exports.caml_pasta_fq_plonk_index_public_inputs
export const caml_pasta_fq_plonk_index_read = __napiModule.exports.caml_pasta_fq_plonk_index_read
export const caml_pasta_fq_plonk_index_write = __napiModule.exports.caml_pasta_fq_plonk_index_write
export const caml_pasta_fq_plonk_proof_batch_verify = __napiModule.exports.caml_pasta_fq_plonk_proof_batch_verify
export const caml_pasta_fq_plonk_proof_create = __napiModule.exports.caml_pasta_fq_plonk_proof_create
export const caml_pasta_fq_plonk_proof_deep_copy = __napiModule.exports.caml_pasta_fq_plonk_proof_deep_copy
export const caml_pasta_fq_plonk_proof_dummy = __napiModule.exports.caml_pasta_fq_plonk_proof_dummy
export const caml_pasta_fq_plonk_proof_verify = __napiModule.exports.caml_pasta_fq_plonk_proof_verify
export const caml_pasta_fq_plonk_verifier_index_create = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_create
export const caml_pasta_fq_plonk_verifier_index_deep_copy = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_deep_copy
export const caml_pasta_fq_plonk_verifier_index_deserialize = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_deserialize
export const caml_pasta_fq_plonk_verifier_index_dummy = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_dummy
export const caml_pasta_fq_plonk_verifier_index_read = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_read
export const caml_pasta_fq_plonk_verifier_index_serialize = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_serialize
export const caml_pasta_fq_plonk_verifier_index_shifts = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_shifts
export const caml_pasta_fq_plonk_verifier_index_write = __napiModule.exports.caml_pasta_fq_plonk_verifier_index_write
export const caml_pasta_fq_poseidon_block_cipher = __napiModule.exports.caml_pasta_fq_poseidon_block_cipher
export const caml_vesta_affine_one = __napiModule.exports.caml_vesta_affine_one
export const camlPastaFpPlonkGateVectorFromBytesExternal = __napiModule.exports.camlPastaFpPlonkGateVectorFromBytesExternal
export const camlPastaFqPlonkGateVectorFromBytesExternal = __napiModule.exports.camlPastaFqPlonkGateVectorFromBytesExternal
export const camlRayonInitSingleThreaded = __napiModule.exports.camlRayonInitSingleThreaded
export const camlRayonSpawnPool = __napiModule.exports.camlRayonSpawnPool
export const camlRayonStartedThreads = __napiModule.exports.camlRayonStartedThreads
export const fp_oracles_create = __napiModule.exports.fp_oracles_create
export const fp_oracles_deep_copy = __napiModule.exports.fp_oracles_deep_copy
export const fp_oracles_dummy = __napiModule.exports.fp_oracles_dummy
export const fq_oracles_create = __napiModule.exports.fq_oracles_create
export const fq_oracles_deep_copy = __napiModule.exports.fq_oracles_deep_copy
export const fq_oracles_dummy = __napiModule.exports.fq_oracles_dummy
export const getNativeCalls = __napiModule.exports.getNativeCalls
export const OS_NAME = __napiModule.exports.OS_NAME
export const pasta_fp_plonk_index_domain_d8_size = __napiModule.exports.pasta_fp_plonk_index_domain_d8_size
export const prover_index_fp_deserialize = __napiModule.exports.prover_index_fp_deserialize
export const prover_index_fp_serialize = __napiModule.exports.prover_index_fp_serialize
export const prover_index_fq_deserialize = __napiModule.exports.prover_index_fq_deserialize
export const prover_index_fq_serialize = __napiModule.exports.prover_index_fq_serialize
export const prover_to_json = __napiModule.exports.prover_to_json
