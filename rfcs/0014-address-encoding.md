## Summary
[summary]: #summary

Change address encoding from Base64 to Base58.

## Motivation

[motivation]: #motivation

First, it's the standard format across other well known cryptocurrencies (Ethereum, Bitcoin). That means most entities in the ecosystem, from end-users to exchanges, will be more familiar and comfortable with Base58 encodings than what we have currently.

Additionally, quoting from the [Bitcoin Wiki](https://en.bitcoin.it/wiki/Base58Check_encoding#Background): 

```
// Why base-58 instead of standard base-64 encoding?
// - Don't want 0OIl characters that look the same in some fonts and
//      could be used to create visually identical looking account numbers.
// - A string with non-alphanumeric characters is not as easily accepted as an account number.
// - E-mail usually won't line-break if there's no punctuation to break at.
// - Doubleclicking selects the whole number as one word if it's all alphanumeric.

```

## Detailed design

[detailed-design]: #detailed-design

I recommend we follow the Bitcoin design, as laid out [here](https://en.bitcoin.it/wiki/Base58Check_encoding#Base58_symbol_chart).

## Drawbacks
[drawbacks]: #drawbacks

- Addresses are longer than Base64.
- It will take some time to implement, perhaps we can use the [Tezos implementation](https://github.com/vbmithr/ocaml-base58)

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

We could continue to use Base64 or a custom encoding. 

I'd recommend Base58 because it is the standard, and it has the benefits enumerated above. I don't see many benefits with developing a custom encoding.

## Prior art
[prior-art]: #prior-art

- [Bitcoin](https://en.bitcoin.it/wiki/Base58Check_encoding#Base58_symbol_chart)
- [Ethereum](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md)
- [Cardano](https://cardanodocs.com/cardano/addresses/)

## Unresolved questions
[unresolved-questions]: #unresolved-questions

1. Should we use a big-endian or little-endian byte order? Both Ethereum and Bitcoin use big-endian encodings.
2. Is it worth spending more time thinking about this or should we just implement what seems to be a standard practice?
