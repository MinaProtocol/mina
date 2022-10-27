import { Field } from "./field.js";

export {
  stringToFields,
  stringFromFields,
  bytesToFields,
  bytesFromFields,
  Bijective,
  TokenId,
  ReceiptChainHash,
  LedgerHash,
  EpochSeed,
  StateHash,
};

// functions for encoding data as field elements

// these methods are not for in-snark computation -- from the snark POV,
// encryption operates on an array of field elements.
// we also assume here that all fields are constant!

// caveat: this is suitable for encoding arbitrary bytes as fields, but not the other way round
// to encode fields as bytes in a recoverable way, you need different methods

function stringToFields(message: string) {
  let bytes = new TextEncoder().encode(message);
  return bytesToFields(bytes);
}

function stringFromFields(fields: Field[]) {
  let bytes = bytesFromFields(fields);
  return new TextDecoder().decode(bytes);
}

const STOP = 0x01;

function bytesToFields(bytes: Uint8Array) {
  // we encode 248 bits (31 bytes) at a time into one field element
  let fields = [];
  let currentBigInt = 0n;
  let bitPosition = 0n;
  for (let byte of bytes) {
    currentBigInt += BigInt(byte) << bitPosition;
    bitPosition += 8n;
    if (bitPosition === 248n) {
      fields.push(Field(currentBigInt.toString()));
      currentBigInt = 0n;
      bitPosition = 0n;
    }
  }
  // encode the final chunk, with an added STOP byte to make the mapping invertible
  currentBigInt += BigInt(STOP) << bitPosition;
  fields.push(Field(currentBigInt.toString()));
  return fields;
}

function bytesFromFields(fields: Field[]) {
  // find STOP byte in last chunk to determine length of byte array
  let lastChunk = fields.pop();
  if (lastChunk === undefined) return new Uint8Array();
  let lastChunkBytes = bytesOfConstantField(lastChunk);
  let i = lastChunkBytes.lastIndexOf(STOP, 30);
  if (i === -1) throw Error("Error (bytesFromFields): Invalid encoding.");
  let bytes = new Uint8Array(fields.length * 31 + i);
  bytes.set(lastChunkBytes.subarray(0, i), fields.length * 31);
  // convert the remaining fields
  i = 0;
  for (let field of fields) {
    bytes.set(bytesOfConstantField(field).subarray(0, 31), i);
    i += 31;
  }
  fields.push(lastChunk);
  return bytes;
}

// bijective fields <--> bytes mapping
// this is suitable for converting *arbitrary* fields AND bytes back and forth
// the interpretation of the fields/bytes array is as digits of a single big integer
// which implies the small caveat that trailing zeroes in the field/bytes array get ignored
// another caveat: the algorithm is O(n^(1 + t)) with t > 0; ~1MB of field elements take about 1-2s to convert

// this needs the exact field size
let p = 0x40000000000000000000000000000000224698fc094cf91b992d30ed00000001n;
let q = 0x40000000000000000000000000000000224698fc0994a8dd8c46eb2100000001n;
let bytesPerBigInt = 32;
let bytesBase = 256n ** BigInt(bytesPerBigInt);

const Bijective = {
  Fp: {
    toBytes: (fields: Field[]) => toBytesBijective(fields, p),
    fromBytes: (bytes: Uint8Array) => toFieldsBijective(bytes, p),

    toString(fields: Field[]) {
      return new TextDecoder().decode(toBytesBijective(fields, p));
    },
    fromString(message: string) {
      let bytes = new TextEncoder().encode(message);
      return toFieldsBijective(bytes, p);
    },
  },
  Fq: {
    toBytes: (fields: Field[]) => toBytesBijective(fields, q),
    fromBytes: (bytes: Uint8Array) => toFieldsBijective(bytes, q),

    toString(fields: Field[]) {
      return new TextDecoder().decode(toBytesBijective(fields, q));
    },
    fromString(message: string) {
      let bytes = new TextEncoder().encode(message);
      return toFieldsBijective(bytes, q);
    },
  },
};

function toBytesBijective(fields: Field[], p: bigint) {
  let fieldsBigInts = fields.map(fieldToBigInt);
  let bytesBig = changeBase(fieldsBigInts, p, bytesBase);
  let bytes = bigIntArrayToBytes(bytesBig, bytesPerBigInt);
  return bytes;
}

function toFieldsBijective(bytes: Uint8Array, p: bigint) {
  let bytesBig = bytesToBigIntArray(bytes, bytesPerBigInt);
  let fieldsBigInts = changeBase(bytesBig, bytesBase, p);
  let fields = fieldsBigInts.map(bigIntToField);
  return fields;
}

// various helpers

function changeBase(digits: bigint[], base: bigint, newBase: bigint) {
  // 1. accumulate digits into one gigantic bigint `x`
  let x = fromBase(digits, base);
  // 2. compute new digits from `x`
  let newDigits = toBase(x, newBase);
  return newDigits;
}

// NOTE: toBase / fromBase are so complicated for performance reasons

function fromBase(digits: bigint[], base: bigint) {
  // compute powers base, base^2, base^4, ..., base^(2^k)
  // with largest k s.t. n = 2^k < digits.length
  let basePowers = [];
  for (let power = base, n = 1; n < digits.length; power **= 2n, n *= 2) {
    basePowers.push(power);
  }
  let k = basePowers.length;
  // pad digits array with zeros s.t. digits.length === 2^k
  digits = digits.concat(Array(2 ** k - digits.length).fill(0n));
  // accumulate [x0, x1, x2, x3, ...] -> [x0 + base*x1, x2 + base*x3, ...] -> [x0 + base*x1 + base^2*(x2 + base*x3=, ...] -> ...
  // until we end up with a single element
  for (let i = 0; i < k; i++) {
    let newDigits = Array(digits.length >> 1);
    let basePower = basePowers[i];
    for (let j = 0; j < newDigits.length; j++) {
      newDigits[j] = digits[2 * j] + basePower * digits[2 * j + 1];
    }
    digits = newDigits;
  }
  console.assert(digits.length === 1);
  let [digit] = digits;
  return digit;
}

function toBase(x: bigint, base: bigint) {
  // compute powers base, base^2, base^4, ..., base^(2^k)
  // with largest k s.t. base^(2^k) < x
  let basePowers = [];
  for (let power = base; power < x; power **= 2n) {
    basePowers.push(power);
  }
  let digits = [x]; // single digit w.r.t base^(2^(k+1))
  // successively split digits w.r.t. base^(2^j) into digits w.r.t. base^(2^(j-1))
  // until we arrive at digits w.r.t. base
  let k = basePowers.length;
  for (let i = 0; i < k; i++) {
    let newDigits = Array(2 * digits.length);
    let basePower = basePowers[k - 1 - i];
    for (let j = 0; j < digits.length; j++) {
      let x = digits[j];
      let high = x / basePower;
      newDigits[2 * j + 1] = high;
      newDigits[2 * j] = x - high * basePower;
    }
    digits = newDigits;
  }
  // pop "leading" zero digits
  while (digits[digits.length - 1] === 0n) {
    digits.pop();
  }
  return digits;
}

// a constant field is internally represented as {value: [0, Uint8Array(32)]}
function bytesOfConstantField(field: Field): Uint8Array {
  let value = (field as any).value;
  if (value[0] !== 0) throw Error("Field is not constant");
  return value[1];
}

function fieldToBigInt(field: Field) {
  let bytes = bytesOfConstantField(field);
  return bytesToBigInt(bytes);
}

function bigIntToField(x: bigint) {
  let field = Field(1);
  (field as any).value = [0, bigIntToBytes(x, 32)];
  return field;
}

function bytesToBigInt(bytes: Uint8Array) {
  let x = 0n;
  let bitPosition = 0n;
  for (let byte of bytes) {
    x += BigInt(byte) << bitPosition;
    bitPosition += 8n;
  }
  return x;
}

function bigIntToBytes(x: bigint, length: number) {
  let bytes = [];
  for (; x > 0; x >>= 8n) {
    bytes.push(Number(x & 0xffn));
  }
  let array = new Uint8Array(bytes);
  if (length === undefined) return array;
  if (array.length > length)
    throw Error(`bigint doesn't fit into ${length} bytes.`);
  let sizedArray = new Uint8Array(length);
  sizedArray.set(array);
  return sizedArray;
}

function bytesToBigIntArray(bytes: Uint8Array, bytesPerBigInt: number) {
  let bigints = [];
  for (let i = 0; i < bytes.byteLength; i += bytesPerBigInt) {
    bigints.push(bytesToBigInt(bytes.subarray(i, i + bytesPerBigInt)));
  }
  return bigints;
}

function bigIntArrayToBytes(bigints: bigint[], bytesPerBigInt: number) {
  let bytes = new Uint8Array(bigints.length * bytesPerBigInt);
  let offset = 0;
  for (let b of bigints) {
    bytes.set(bigIntToBytes(b, bytesPerBigInt), offset);
    offset += bytesPerBigInt;
  }
  // remove zero bytes
  let i = bytes.byteLength - 1;
  for (; i >= 0; i--) {
    if (bytes[i] !== 0) break;
  }
  return bytes.slice(0, i + 1);
}

// encoding of fields as base58, compatible with ocaml encodings (provided the versionByte and versionNumber are the same)

const Ledger = {
  encoding: {
    toBase58(ocamlBytes: any, versionByte: number): string {
      throw "unimplemented";
    },
    ofBase58(base58: string, versionByte: number): any {
      throw "unimplemented";
    },
    versionBytes: {
      tokenIdKey: 0,
      receiptChainHash: 1,
      ledgerHash: 2,
      epochSeed: 3,
      stateHash: 4,
    },
  },
};

function fieldToBase58(x: Field, versionByte: number, versionNumber?: number) {
  try {
    x = x.toConstant();
  } catch (err: any) {
    err.message =
      `Cannot read the value of a variable for base58 encoding.\n` +
      err.message;
    throw err;
  }
  let bytes = [...(x as any as InternalConstantField).value[1]];
  if (versionNumber !== undefined) bytes.unshift(versionNumber);
  let binaryString = String.fromCharCode(...bytes);
  let ocamlBytes = { t: 9, c: binaryString, l: bytes.length };
  return Ledger.encoding.toBase58(ocamlBytes, versionByte);
}
function fieldFromBase58(
  base58: string,
  versionByte: number,
  versionNumber?: number
): Field {
  let ocamlBytes = Ledger.encoding.ofBase58(base58, versionByte);
  let bytes = [...ocamlBytes.c].map((_, i) => ocamlBytes.c.charCodeAt(i));
  if (versionNumber !== undefined) bytes.shift();
  let uint8array = new Uint8Array(32);
  uint8array.set(bytes);
  return Object.assign(Object.create(Field(1).constructor.prototype), {
    value: [0, uint8array],
  });
}

function customEncoding(versionByte: () => number, versionNumber?: number) {
  return {
    toBase58(field: Field) {
      return fieldToBase58(field, versionByte(), versionNumber);
    },
    fromBase58(base58: string) {
      return fieldFromBase58(base58, versionByte(), versionNumber);
    },
  };
}

const RECEIPT_CHAIN_HASH_VERSION = 1;
const LEDGER_HASH_VERSION = 1;
const EPOCH_SEED_VERSION = 1;
const STATE_HASH_VERSION = 1;

const TokenId = customEncoding(() => Ledger.encoding.versionBytes.tokenIdKey);
const ReceiptChainHash = customEncoding(
  () => Ledger.encoding.versionBytes.receiptChainHash,
  RECEIPT_CHAIN_HASH_VERSION
);
const LedgerHash = customEncoding(
  () => Ledger.encoding.versionBytes.ledgerHash,
  LEDGER_HASH_VERSION
);
const EpochSeed = customEncoding(
  () => Ledger.encoding.versionBytes.epochSeed,
  EPOCH_SEED_VERSION
);
const StateHash = customEncoding(
  () => Ledger.encoding.versionBytes.stateHash,
  STATE_HASH_VERSION
);

type InternalConstantField = { value: [0, Uint8Array] };
