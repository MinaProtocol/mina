open Core_kernel

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

(* DEFINITIONS OF CONSTANTS FOR KECCAK *)

(* Length of the square matrix side of Keccak states *)
let dim = 5

(* value `l` in Keccak, ranges from 0 to 6 (7 possible values) *)
let length = 6

(* width of the lane of the state, meaning the length of each word in bits (64) *)
let word = Int.pow 2 length

(* length of the state in bits, meaning the 5x5 matrix of words in bits (1600) *)
let state = Int.pow 2 word

(* number of rounds of the Keccak permutation function depending on the value `l` (24) *)
let rounds = 12 + (2 * length)

(* Length of hash output *)
let eth_output = 256

(* Capacity in Keccak256 *)
let eth_capacity = 512

(* Bitrate in Keccak256 (1088) *)
let eth_bitrate = state - eth_capacity

(* Creates the 5x5 table of rotation offset for Keccak modulo 64
 * | x \ y |  0 |  1 |  2 |  3 |  4 |
 * | ----- | -- | -- | -- | -- | -- |
 * | 0     |  0 | 36 |  3 | 41 | 18 |
 * | 1     |  1 | 44 | 10 | 45 |  2 |
 * | 2     | 62 |  6 | 43 | 15 | 61 |
 * | 3     | 28 | 55 | 25 | 21 | 56 |
 * | 4     | 27 | 20 | 39 |  8 | 14 |
 *)
let rot_tab =
  [| [| 0; 36; 3; 41; 18 |]
   ; [| 1; 44; 10; 45; 2 |]
   ; [| 62; 6; 43; 15; 61 |]
   ; [| 28; 55; 25; 21; 56 |]
   ; [| 27; 20; 39; 8; 14 |]
  |]

(*
(* Round constants for the 24 rounds of Keccak for the iota algorithm *)
let rc = [|
    0x0000000000000001;
    0x0000000000008082;
    0x800000000000808A;
    0x8000000080008000;
    0x000000000000808B;
    0x0000000080000001;
    0x8000000080008081;
    0x8000000000008009;
    0x000000000000008A;
    0x0000000000000088;
    0x0000000080008009;
    0x000000008000000A;
    0x000000008000808B;
    0x800000000000008B;
    0x8000000000008089;
    0x8000000000008003;
    0x8000000000008002;
    0x8000000000000080;
    0x000000000000800A;
    0x800000008000000A;
    0x8000000080008081;
    0x8000000000008080;
    0x0000000080000001;
    0x8000000080008008 |]
*)

(* Auxiliary function to check composition of 8 bytes into a 64-bit word *)
let check_bytes_to_word (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (word : Circuit.Field.t) (word_bytes : Circuit.Field.t list) =
  let open Circuit in
  let composition =
    List.foldi word_bytes ~init:Field.zero ~f:(fun i acc x ->
        let shift = Field.constant @@ Common.two_pow (module Circuit) (8 * i) in
        (* TODO: necessary step to check values? *)
        Field.Assert.equal
          (Field.constant @@ Common.two_pow (module Circuit) (8 * i))
          shift ;
        Field.(acc + (x * shift)) )
  in
  Field.Assert.equal word composition

(* KECCAK HASH FUNCTION IMPLEMENTATION *)

(* Pads a message M as:
   * M || pad[x](|M|)
   * Padding rule 10*1.
   * The padded message vector will start with the message vector
   * followed by the 10*1 rule to fulfil a length that is a multiple of bitrate.
*)
let pad (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (_bitrate : int) : Circuit.Field.t list =
  (*TODO: decide how to represent messages *)
  (*let message_length = List.length message in
    let pad_length = bitrate - (message_length mod bitrate) in
    let pad = [Circuit.Field.one] @ (List.init (pad_length - 2) ~f:(fun _ -> Circuit.Field.zero)) @ [Circuit.Field.one] in
    message @ pad *)
  (* we need padded message length to be a multiple of bitrate *)
  message

(* Keccak sponge function for 1600 bits of state width
 * Need to split the message into blocks of 1088 bits
 *)
let sponge (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (padded_message : Circuit.Field.t list) (bitrate : int) (capacity : int)
    (output_length : int) : Circuit.Field.t list =
  (* check that the padded message is a multiple of bitrate *)
  assert (List.length padded_message * 8 mod bitrate = 0) ;

  (* absorb *)
  (*
    let root_state = [[0u64; dim]; dim];
    let mut state = root_state;
    // split into blocks of bitrate bits
    // for each block of bitrate bits in the padded message -> this is bitrate/8 bytes
    for block in padded_message.chunks(bitrate / 8) {
        let mut padded_block = block.to_vec();
        // pad the block with 0s to up to 1600 bits
        for _ in 0..(capacity / 8) {
            // (capacity / 8) zero bytes
            padded_block.push(0x00);
        }
        // padded with zeros each block until they are 1600 bit long
        assert_eq!(
            padded_block.len() * 8,
            STATE,
            "Padded block does not have 1600 bits"
        );
        let block_state = from_bytes_to_state(&padded_block);
        // xor the state with the padded block
        state = xor_state(state, block_state);
        // apply the permutation function to the xored state
        state = keccak_permutation(state);
    }

    (* squeeze *)
    let mut output = from_state_to_bytes(state)[0..(bitrate / 8)].to_vec();
    while output.len() < output_length / 8 {
        // apply the permutation function to the state
        state = keccak_permutation(state);
        // append the output of the permutation function to the output
        output.append(&mut from_state_to_bytes(state)[0..(bitrate / 8)].to_vec());
    }
    // return the first 256 bits of the output
    let hashed = output[0..(output_length / 8)].to_vec().try_into().unwrap();
    hashed
    *)
  padded_message

(* Keccak hash function, does not accept messages whose length is not a multiple of 8 bits.
   * message should be passed as list of 1byte Cvars.
   * The message will be parsed as follows:
   * - the first byte of the message will be the least significant byte of the first word of the state (A[0][0])
   * - the 10*1 pad will take place after the message, until reaching the bit length BITRATE.
   * - then, {0} pad will take place to finish the 1600 bits of the state.
*)
let hash (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (bitrate : int) (capacity : int)
    (output_length : int) : Circuit.Field.t list =
  assert (bitrate > 0) ;
  assert (capacity > 0) ;
  assert (output_length > 0) ;
  assert (bitrate + capacity = state) ;
  assert (bitrate mod 8 = 0) ;
  assert (output_length mod 8 = 0) ;

  (*TODO: replace with output of keccak*)
  let padded = pad (module Circuit) message bitrate in
  let hash = sponge (module Circuit) padded bitrate capacity output_length in
  hash

module State = struct
  module Cvar = Snarky_backendless.Cvar

  type 'a matrix = 'a array array

  let of_bytes (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (bytestring : Circuit.Field.t list) : Circuit.Field.t matrix =
    let open Circuit in
    assert (List.length bytestring = 200) ;
    let state = Array.make_matrix ~dimx:dim ~dimy:dim Field.zero in
    for y = 0 to dim do
      for x = 0 to dim do
        for z = 0 to word / 8 do
          let index = (8 * ((dim * y) + x)) + z in
          (* Field element containing value 2^(8*z) *)
          let shift_field =
            Common.bignum_bigint_to_field
              (module Circuit)
              Bignum_bigint.(pow (of_int 2) (of_int (Int.( * ) 8 z)))
          in
          let shift = Field.constant shift_field in
          (* TODO: Does this generate automatic generic gates to check composition? *)
          Field.Assert.equal (Field.constant shift_field) shift ;
          state.(x).(y) <-
            Field.(state.(x).(y) + (shift * List.nth_exn bytestring index))
        done
      done
    done ;
    state

  let as_prover_to_bytes (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (state : Circuit.Field.t matrix) : Circuit.Field.t list =
    let open Circuit in
    assert (Array.length state = dim && Array.length state.(0) = dim) ;
    let bytestring = Array.create ~len:200 Field.zero in
    let bytes_per_word = word / 8 in
    for y = 0 to dim do
      for x = 0 to dim do
        let base_index = bytes_per_word * ((dim * y) + x) in
        for z = 0 to bytes_per_word do
          let index = base_index + z in
          let byte =
            exists Field.typ ~compute:(fun () ->
                let word =
                  Common.cvar_field_to_bignum_bigint_as_prover
                    (module Circuit)
                    state.(x).(y)
                in
                let power = 8 * (z + 1) in
                let offset = Bignum_bigint.(pow (of_int 2) (of_int power)) in
                let byte = Bignum_bigint.(word % offset) in
                Common.bignum_bigint_to_field (module Circuit) byte )
          in
          bytestring.(index) <- byte
        done ;

        (* TODO: Does this generate automatic generic gates to check decomposition? *)

        (* Create a list containing the elements of bytestring from base_index to base_index + 7 *)
        let word_bytes =
          Array.to_list
          @@ Array.sub bytestring ~pos:base_index ~len:bytes_per_word
        in

        (* Assert correct decomposition of bytes from state *)
        check_bytes_to_word (module Circuit) state.(x).(y) word_bytes
      done
    done ;
    Array.to_list bytestring

  let xor (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (input1 : Circuit.Field.t matrix) (input2 : Circuit.Field.t matrix) :
      Circuit.Field.t matrix =
    let open Circuit in
    assert (Array.length input1 = dim && Array.length input1.(0) = dim) ;
    assert (Array.length input2 = dim && Array.length input2.(0) = dim) ;
    let output = Array.make_matrix ~dimx:dim ~dimy:dim Field.zero in
    for y = 0 to dim do
      for x = 0 to dim do
        output.(x).(y) <-
          Bitwise.bxor64 (module Circuit) input1.(x).(y) input2.(x).(y)
      done
    done ;
    output
end
