const assert = require('assert');
const mina = require("../../../../_build/default/src/app/client_sdk/client_sdk.bc.js").minaSDK;
const fs = require('fs');

// helpers
// =======

function hexstring_to_typedarray(hexString) {
    // checks
    if (hexString.length % 2 != 0) {
        throw "invalid length";
    }

    const re = /[0-9A-Fa-f]*/g;
    if (!re.test(hexString)) {
        throw "invalid character";
    }

    // conversion
    return Uint8Array.from(Buffer.from(hexString, 'hex'));
}

// handy function to convert little-endian encoded hexstrings into their decimal counterparts 
function hex_to_decimal(hex) {
    let hex_be = hex.match(/../g).reverse().join('');
    let bn = BigInt('0x' + hex_be);
    return bn.toString(10);
}

// hash_bytearray
// ==============
// Note: the hash_bytearray API does not have test vectors at the moment.

// hash(0xdeadbeef)
let input = hexstring_to_typedarray("deadbeef");
assert(mina.hashBytearray(input) == "59b88198cfe25b4f730bafb48593e5b60a94f022cdc168e1ebbfe371f9935f27");

// compare the two APIs on the empty input
input = hexstring_to_typedarray("");
assert(mina.hashBytearray(input) == mina.hashFieldElems([]));

// hash_field_elems
// ================

// read test vectors file
let rawdata = fs.readFileSync('src/app/client_sdk/tests/poseidon_test_vectors.json');
let test_vectors = JSON.parse(rawdata);

// iterate over every test vector
test_vectors.map((test_vector, idx) => {
    // hash
    const input = test_vector.input.map(hexString =>
        hexstring_to_typedarray(hexString)
    );
    let digest = mina.hashFieldElems(input);

    // expected result
    assert(test_vector.output == digest);
})

// negative tests

// bad hexstring length
assert.throws(() => {
    let hexString = "01110101101010101010101010101010101010101";
    let input = hexstring_to_typedarray(hexString)
    mina.hashFieldElems([input]);
});

// bad input: not an array of uint8array
assert.throws(() => {
    let hexString = "0111010110101010101010101010101010101010";
    let input = hexstring_to_typedarray(hexString)
    mina.hashFieldElems(input);
});

// passed null value
assert.throws(() => {
    mina.hashFieldElems(null); // <-- null!
});

// passed field element larger or equal to the order
let order = mina.hashOrder.c;

assert.throws(() => {
    let input = hexstring_to_typedarray(order);
    mina.hashFieldElems([input]);
});

assert.throws(() => {
    let input = hexstring_to_typedarray(order);
    input[0] += 1;
    mina.hashFieldElems([input]);
});
