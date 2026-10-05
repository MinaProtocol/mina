module Circuit := Kimchi_pasta_snarky_backend.Step_impl

(** Endianness type. *)
type endianness = Big | Little

(** Gadget for NIST SHA-3 function for output lengths 224/256/384/512.

    @param inp_endian Endianness of the input (default is Big)
    @param out_endian Endianness of the output (default is Big)
    @param byte_checks Flag to enable input byte checks (default is false).
                       Outputs are always constrained.
    @param len Output length of the hash function (224|256|384|512)
    @param message Arbitrary length list of Cvars representing the input to
                   the hash function where each of them is a byte
    @return List of Cvars representing the output of the hash function where
            each of them is a byte *)
val nist_sha3 :
     ?inp_endian:endianness
  -> ?out_endian:endianness
  -> ?byte_checks:bool
  -> int
  -> Circuit.Field.t list
  -> Circuit.Field.t list

(** Gadget for Keccak hash function for the parameters used in Ethereum.

    @param inp_endian Endianness of the input (default is Big)
    @param out_endian Endianness of the output (default is Big)
    @param byte_checks Flag to enable input byte checks (default is false).
                       Outputs are always constrained.
    @param message Arbitrary length list of Cvars representing the input to
                   the hash function where each of them is a byte
    @return List of 256 Cvars representing the output of the hash function
            where each of them is a byte *)
val ethereum :
     ?inp_endian:endianness
  -> ?out_endian:endianness
  -> ?byte_checks:bool
  -> Circuit.Field.t list
  -> Circuit.Field.t list

(** Gadget for pre-NIST SHA-3 function for output lengths 224/256/384/512.
    Note that when calling with output length 256 this is equivalent to the
    [ethereum] function.

    @param inp_endian Endianness of the input (default is Big)
    @param out_endian Endianness of the output (default is Big)
    @param byte_checks Flag to enable input byte checks (default is false).
                       Outputs are always constrained.
    @param len Output length of the hash function (224|256|384|512)
    @param message Arbitrary length list of Cvars representing the input to
                   the hash function where each of them is a byte
    @return List of Cvars representing the output of the hash function where
            each of them is a byte *)
val pre_nist :
     ?inp_endian:endianness
  -> ?out_endian:endianness
  -> ?byte_checks:bool
  -> int
  -> Circuit.Field.t list
  -> Circuit.Field.t list
