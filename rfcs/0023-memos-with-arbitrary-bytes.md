## Summary

Allow arbitrary bytes in the user command memo field as alternative to
Blake2 digests.

## Motivation

When creating a transaction, users may wish to add a meaningful
description. The memo field is a convenient place for such a
description. The description could be viewed in a wallet app.

## Detailed design

Memos that contain Blake2 digests should still be available. To
distinguish memos with digests from memos of bytes, we can prepend a
tag byte to the memo string.

Memos are still of fixed length, but the bytes provided may not fill
up the memo.  The length is given in another prepended byte. For
digests, that length is always 32. For memos of bytes where the length
is less than 32, the memo is right-padded with null bytes (the OCaml
character '\x00').

To create a memo of bytes, the input can be provided as an OCaml
string or a value of type "bytes". The length of that input is
verified to be no greater than 32.

## Drawbacks

The tag and length bytes increase the size of the memo field, so that
the size of data processed by transaction SNARKs increases, increasing
the times for proving.

Giving users full control of the memo field allows them to put illegal
or morally dubious content there, which could harm the reputation of
Coda.

## Rationale and alternatives

We could distinguish wholly-arbitrary bytes from human-readable byte
sequences, by requiring the input to be UTF-8 in the latter case. A
third tag could be used for that purpose. That would add a small
amount of complexity to the API.

The current memo data size of 32, which is derived from the Blake2
digest size, could be increased, at the expense of more work for the
SNARK.

Of course, we could leave the memo contain as-is, containing only
Blake2 digests, which would avoid the drawbacks mentioned.

## Prior art

RFC #2708 implements the strategy described here. The current wallet
design allows reading and viewing of memos in transactions.

## Unresolved questions

The performance impact of this change has not been evaluated.

Should we enforce full memo validity, as implemented in the "is_valid"
function in the implementation, in the SNARK? If not, what aspects of
the memo should be enforced? Arguably, the structure of the memo bytes
don't affect the protocol.

It's unknown how eventual Coda users will make use of this facility
beyond what the wallet implementation provides.
