v0.6 2018-07-05 Paris (France)
------------------------------

- *breaking change* API:
  From a consensus between people who use `digestif`, we decide to delete `*.Bytes.*` and `*.Bigstring.*` sub-modules.
  We replace it by `feed_{bytes,string,bigstring}` (`digest_`, and `hmac_` too)
- *breaking change* semantic: streaming and referentially transparent
  Add `feedi_{bytes,string,bigstring}`, `digesti_{bytes,string,bigstring}` and `hmaci_{bytes,string,bigstring}`
  (@hannesm, @cfcs)
- Constant time for `eq`/`neq` functions
  (@cfcs)
- *breaking change* semantic on `compare` and `unsafe_compare`:
  `compare` is not a lexicographical comparison function (rename to `unsafe_compare`)
  (@cfcs)
- Add `consistent_of_hex` (@hannesm, @cfcs)

v0.4 2017-10-30 Mysore / ಮೈಸೂರು (India)
----------------------------------------

- Add an automatised test suit
- Add the RIPEMD160 hash algorithm
- Add the BLAKE2S hash algorithm
- Update authors
- Add `feed_bytes` and `feed_bigstring` for `Bytes` and `Bigstring`

v0.3 2017-07-21 Phnom Penh (Cambodia)
-------------------------------------

- Fixed issue #6
- Make a new test suit

v0.2 2017-07-05 Phnom Penh (Cambodia)
-------------------------------------

- Implementation of the hash function in pure OCaml
- Link improvement (à la `mtime`) to decide to use the C stub or the OCaml implementation
- Improvement of the common interface (pretty-print, type t, etc.)

v0.1 2017-05-12 Rạch Giá (Vietnam)
------------------------------------

- First release
