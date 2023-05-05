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
let rot_table =
  [| [| 0; 36; 3; 41; 18 |]
   ; [| 1; 44; 10; 45; 2 |]
   ; [| 62; 6; 43; 15; 61 |]
   ; [| 28; 55; 25; 21; 56 |]
   ; [| 27; 20; 39; 8; 14 |]
  |]

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

(* Internal struct for Keccak State *)

module State = struct
  module Cvar = Snarky_backendless.Cvar

  type 'a matrix = 'a array array

  (* Creates a state formed by a matrix of 5x5 Cvar zeros *)
  let zeros (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) :
      Circuit.Field.t matrix =
    let open Circuit in
    let state = Array.make_matrix ~dimx:dim ~dimy:dim Field.zero in
    state

  (* Converts a list of bytes to a matrix of Field elements *)

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

(* KECCAK HASH FUNCTION IMPLEMENTATION *)

(* Pads a message M as:
   * M || pad[x](|M|)
   * Padding rule 10*1.
   * The padded message vector will start with the message vector
   * followed by the 10*1 rule to fulfil a length that is a multiple of bitrate (in bytes)
*)
let pad (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (bitrate : int) : Circuit.Field.t list =
  let open Circuit in
  (* Find out desired length of the padding in bytes *)
  (* If message is already bitrate bits, need to pad full bitrate again *)
  let extra_bytes = (bitrate / 8) - (List.length message mod bitrate) in
  (* 0x01 0x00 ... 0x00 0x80 or 0x81 *)
  let last_field = Common.two_pow (module Circuit) 7 in
  let last = Field.constant @@ Common.two_pow (module Circuit) 7 in
  (* Create the padding vector *)
  let pad = Array.create ~len:extra_bytes Field.zero in
  pad.(0) <- Field.one ;
  pad.(extra_bytes - 1) <- Field.add pad.(extra_bytes - 1) last ;
  Field.Assert.equal (Field.constant last_field) last ;
  (* Cast the padding array to a list *)
  let pad = Array.to_list pad in
  (* Return the padded message *)
  message @ pad

(* 
 * First algrithm in the compression step of Keccak for 64-bit words.
 * C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4]
 * D[x] = C[x-1] xor ROT(C[x+1], 1)
 * E[x,y] = A[x,y] xor D[x]
 * In the Keccak reference, it corresponds to the `theta` algorithm.
 * We use the first index of the state array as the x coordinate and the second index as the y coordinate.
 *)
let theta (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) : Circuit.Field.t State.matrix =
  let open Circuit in
  let state_a = state in
  let state_c = Array.create ~len:5 Field.zero in
  let state_d = Array.create ~len:5 Field.zero in
  let state_e = State.zeros (module Circuit) in
  (* XOR the elements of each row together *)
  (* for all x in {0..4}: C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4] *)
  for x = 0 to dim do
    state_c.(x) <-
      Bitwise.(
        bxor64
          (module Circuit)
          (bxor64
             (module Circuit)
             (bxor64
                (module Circuit)
                (bxor64 (module Circuit) state_a.(x).(0) state_a.(x).(1))
                state_a.(x).(2) )
             state_a.(x).(3) )
          state_a.(x).(4))
  done ;
  (* for all x in {0..4}: D[x] = C[x-1] xor ROT(C[x+1], 1) *)
  for x = 0 to dim do
    state_d.(x) <-
      Bitwise.(
        bxor64
          (module Circuit)
          state_c.((x - 1) mod 5)
          (rot64 (module Circuit) state_c.((x + 1) mod 5) 1 Left)) ;
    (* for all x in {0..4} and y in {0..4}: E[x,y] = A[x,y] xor D[x] *)
    for y = 0 to dim do
      state_e.(x).(y) <-
        Bitwise.(bxor64 (module Circuit) state_a.(x).(y) state_d.(x))
    done
  done ;
  state_e

(*
 * Second and third steps in the compression step of Keccak for 64-bit words.
 * B[y,2x+3y] = ROT(E[x,y], r[x,y])
 * which is equivalent to the `rho` algorithm followed by the `pi` algorithm in the Keccak reference as follows:
 * rho:
 * A[0,0] = a[0,0]
 * | x |  =  | 1 |
 * | y |  =  | 0 |
 * for t = 0 to 23 do
 *   A[x,y] = ROT(a[x,y], (t+1)(t+2)/2 mod 64)))
 *   | x |  =  | 0  1 |   | x |
 *   |   |  =  |      | * |   |
 *   | y |  =  | 2  3 |   | y |
 * end for
 * pi:
 * for x = 0 to 4 do
 *   for y = 0 to 4 do
 *     | X |  =  | 0  1 |   | x |
 *     |   |  =  |      | * |   |
 *     | Y |  =  | 2  3 |   | y |
 *     A[X,Y] = a[x,y]
 *   end for
 * end for
 * We use the first index of the state array as the x coordinate and the second index as the y coordinate. 
 *)
let pi_rho (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) : Circuit.Field.t State.matrix =
  let state_e = state in
  let state_b = State.zeros (module Circuit) in
  (* for all x in {0..4} and y in {0..4}: B[y,2x+3y] = ROT(E[x,y], r[x,y]) *)
  for x = 0 to dim do
    for y = 0 to dim do
      state_b.(y).(((2 * x) + (3 * y)) mod dim) <-
        Bitwise.rot64 (module Circuit) state_e.(x).(y) rot_table.(x).(y) Left
    done
  done ;
  state_b

(* 
 * Fourth step of the compression function of Keccak for 64-bit words.
 * F[x,y] = B[x,y] xor ((not B[x+1,y]) and B[x+2,y])
 * It corresponds to the chi algorithm in the Keccak reference.
 * for y = 0 to 4 do
 *   for x = 0 to 4 do
 *     A[x,y] = a[x,y] xor ((not a[x+1,y]) and a[x+2,y])
 *   end for
 * end for   
 *)
let chi (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) : Circuit.Field.t State.matrix =
  let state_b = state in
  let state_f = State.zeros (module Circuit) in
  (* for all x in {0..4} and y in {0..4}: F[x,y] = B[x,y] xor ((not B[x+1,y]) and B[x+2,y]) *)
  for x = 0 to dim do
    for y = 0 to dim do
      state_f.(x).(y) <-
        Bitwise.(
          bxor64
            (module Circuit)
            state_b.(x).(y)
            (band64
               (module Circuit)
               (bnot64_unchecked (module Circuit) state_b.((x + 1) mod 5).(y))
               state_b.((x + 2) mod 5).(y) ))
    done
  done ;
  (* We can use unchecked NOT because the length of the input is constrained to be
     64 bits thanks to the fact that it is the output of a previous Xor64 *)
  state_f

(*
 * Fifth step of the permutation function of Keccak for 64-bit words.
 * It takes the word located at the position (0,0) of the state and XORs it with the round constant.
 *)
let iota (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) (round : int) :
    Circuit.Field.t State.matrix =
  let open Circuit in
  (* Round constants for the 24 rounds of Keccak for the iota algorithm *)
  let rc =
    exists (Typ.array ~length:24 Field.typ) ~compute:(fun () ->
        let rc =
          [| "0000000000000001"
           ; "0000000000008082"
           ; "800000000000808A"
           ; "8000000080008000"
           ; "000000000000808B"
           ; "0000000080000001"
           ; "8000000080008081"
           ; "8000000000008009"
           ; "000000000000008A"
           ; "0000000000000088"
           ; "0000000080008009"
           ; "000000008000000A"
           ; "000000008000808B"
           ; "800000000000008B"
           ; "8000000000008089"
           ; "8000000000008003"
           ; "8000000000008002"
           ; "8000000000000080"
           ; "000000000000800A"
           ; "800000008000000A"
           ; "8000000080008081"
           ; "8000000000008080"
           ; "0000000080000001"
           ; "8000000080008008"
          |]
        in
        (* TODO: instead of Bignum_bigint and strings, perhaps use some u64 equivalent? *)
        Array.map rc ~f:(fun x ->
            let x = Bignum_bigint.of_string x in
            Common.bignum_bigint_to_field (module Circuit) x ) )
  in
  let state_g = state in
  state_g.(0).(0) <-
    Bitwise.(bxor64 (module Circuit) state_g.(0).(0) rc.(round)) ;
  state_g

(* The round applies the lambda function and then chi and iota
 * It consists of the concatenation of the theta, rho, and pi algorithms.
 * lambda = pi o rho o theta
 * Thus:
 * iota o chi o pi o rho o theta
 *)
let round (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) (round : int) :
    Circuit.Field.t State.matrix =
  let state_a = state in
  let state_e = theta (module Circuit) state_a in
  let state_b = pi_rho (module Circuit) state_e in
  let state_f = chi (module Circuit) state_b in
  let state_d = iota (module Circuit) state_f round in

  state_d

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
  let root_state = State.zeros (module Circuit) in
  let state = root_state in

  (* split into blocks of bitrate bits *)
  (* for each block of bitrate bits in the padded message -> this is bitrate/8 bytes *)

  
  
  padded_message

(*
* Keccak hash function with input message passed as list of 1byte Cvars.
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
