open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

let tests_enabled = true

(* Endianness type *)
type endianness = Big | Little

(* DEFINITIONS OF CONSTANTS FOR KECCAK *)

(* Length of the square matrix side of Keccak states *)
let keccak_dim = 5

(* value `l` in Keccak, ranges from 0 to 6 (7 possible values) *)
let keccak_ell = 6

(* width of the lane of the state, meaning the length of each word in bits (64) *)
let keccak_word = Int.pow 2 keccak_ell

(* number of bytes that fit in a word (8) *)
let bytes_per_word = keccak_word / 8

(* length of the state in bits, meaning the 5x5 matrix of words in bits (1600) *)
let keccak_state_length = Int.pow keccak_dim 2 * keccak_word

(* number of rounds of the Keccak permutation function depending on the value `l` (24) *)
let keccak_rounds = 12 + (2 * keccak_ell)

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

let round_consts =
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

(* Auxiliary function to check composition of 8 bytes into a 64-bit word *)
let check_bytes_to_word (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (word : Circuit.Field.t) (word_bytes : Circuit.Field.t array) =
  let open Circuit in
  let composition =
    Array.foldi word_bytes ~init:Field.zero ~f:(fun i acc x ->
        let shift = Field.constant @@ Common.two_pow (module Circuit) (8 * i) in
        Field.(acc + (x * shift)) )
  in
  Field.Assert.equal word composition

(* Internal struct for Keccak State *)

module State = struct
  type 'a matrix = 'a array array

  (* Creates a state formed by a matrix of 5x5 Cvar zeros *)
  let zeros (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f) :
      Circuit.Field.t matrix =
    let open Circuit in
    let state =
      Array.make_matrix ~dimx:keccak_dim ~dimy:keccak_dim Field.zero
    in
    state

  (* Updates the cells of a state with new values *)
  let update (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      ~(prev : Circuit.Field.t matrix) ~(next : Circuit.Field.t matrix) =
    for x = 0 to keccak_dim - 1 do
      prev.(x) <- next.(x)
    done

  (* Converts a list of bytes to a matrix of Field elements *)
  let of_bytes (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (bytestring : Circuit.Field.t list) : Circuit.Field.t matrix =
    let open Circuit in
    assert (List.length bytestring = 200) ;
    let bytestring = Array.of_list bytestring in
    let state =
      Array.make_matrix ~dimx:keccak_dim ~dimy:keccak_dim Field.zero
    in
    for y = 0 to keccak_dim - 1 do
      for x = 0 to keccak_dim - 1 do
        let idx = bytes_per_word * ((keccak_dim * y) + x) in
        (* Create an array containing the 8 bytes starting on idx that correspond to the word in [x,y] *)
        let word_bytes = Array.sub bytestring ~pos:idx ~len:bytes_per_word in
        for z = 0 to bytes_per_word - 1 do
          (* Field element containing value 2^(8*z) *)
          let shift_field =
            Common.bignum_bigint_to_field
              (module Circuit)
              Bignum_bigint.(pow (of_int 2) (of_int (Int.( * ) 8 z)))
          in
          let shift = Field.constant shift_field in
          state.(x).(y) <- Field.(state.(x).(y) + (shift * word_bytes.(z)))
        done
      done
    done ;

    state

  (* Converts a state of cvars to a list of bytes as cvars and creates constraints for it *)
  let as_prover_to_bytes (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (state : Circuit.Field.t matrix) : Circuit.Field.t list =
    let open Circuit in
    assert (
      Array.length state = keccak_dim && Array.length state.(0) = keccak_dim ) ;
    let state_length_in_bytes = keccak_state_length / 8 in
    let bytestring =
      Array.init state_length_in_bytes ~f:(fun idx ->
          exists Field.typ ~compute:(fun () ->
              (* idx = z + 8 * ((dim * y) + x) *)
              let z = idx % bytes_per_word in
              let x = idx / bytes_per_word % keccak_dim in
              let y = idx / bytes_per_word / keccak_dim in
              (*  [7 6 5 4 3 2 1 0] [x=0,y=1] [x=0,y=2] [x=0,y=3] [x=0,y=4]
               *          [x=1,y=0] [x=1,y=1] [x=1,y=2] [x=1,y=3] [x=1,y=4]
               *          [x=2,y=0] [x=2,y=1] [x=2,y=2] [x=2,y=3] [x=2,y=4]
               *          [x=3,y=0] [x=3,y=1] [x=3,y=2] [x=3,y=3] [x=3,y=4]
               *          [x=4,y=0] [x=4,y=1] [x=4,y=0] [x=4,y=3] [x=4,y=4]
               *)
              let word =
                Common.cvar_field_to_bignum_bigint_as_prover
                  (module Circuit)
                  state.(x).(y)
              in
              let byte =
                Common.bignum_bigint_to_field
                  (module Circuit)
                  Bignum_bigint.((word asr Int.(8 * z)) land of_int 0xff)
              in
              byte ) )
    in
    (* Check all words are composed correctly from bytes *)
    for y = 0 to keccak_dim - 1 do
      for x = 0 to keccak_dim - 1 do
        let idx = bytes_per_word * ((keccak_dim * y) + x) in
        (* Create an array containing the 8 bytes starting on idx that correspond to the word in [x,y] *)
        let word_bytes = Array.sub bytestring ~pos:idx ~len:bytes_per_word in
        (* Assert correct decomposition of bytes from state *)
        check_bytes_to_word (module Circuit) state.(x).(y) word_bytes
      done
    done ;

    Array.to_list bytestring

  let xor (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (input1 : Circuit.Field.t matrix) (input2 : Circuit.Field.t matrix) :
      Circuit.Field.t matrix =
    assert (
      Array.length input1 = keccak_dim && Array.length input1.(0) = keccak_dim ) ;
    assert (
      Array.length input2 = keccak_dim && Array.length input2.(0) = keccak_dim ) ;

    (* Calls Bitwise.bxor64 on each pair (x,y) of the states input1 and input2
       and outputs the output Cvars as a new matrix *)
    Array.map2_exn input1 input2
      ~f:(Array.map2_exn ~f:(Bitwise.bxor64 (module Circuit)))
end

(* KECCAK HASH FUNCTION IMPLEMENTATION *)

(* Computes the number of required extra bytes to pad a message of length bytes *)
let bytes_to_pad (rate : int) (length : int) =
  (rate / 8) - (length mod (rate / 8))

(* Pads a message M as:
 * M || pad[x](|M|)
 * Padding rule 0x06 ..0*..1.
 * The padded message vector will start with the message vector
 * followed by the 0*1 rule to fulfil a length that is a multiple of rate (in bytes)
 * (This means a 0110 sequence, followed with as many 0s as needed, and a final 1 bit)
 *)
let pad_nist (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (rate : int) : Circuit.Field.t list =
  let open Circuit in
  (* Find out desired length of the padding in bytes *)
  (* If message is already rate bits, need to pad full rate again *)
  let extra_bytes = bytes_to_pad rate (List.length message) in
  (* 0x06 0x00 ... 0x00 0x80 or 0x86 *)
  let last_field = Common.two_pow (module Circuit) 7 in
  let last = Field.constant last_field in
  (* Create the padding vector *)
  let pad = Array.init extra_bytes ~f:(fun _ -> Field.zero) in
  pad.(0) <- Field.of_int 6 ;
  pad.(extra_bytes - 1) <- Field.add pad.(extra_bytes - 1) last ;
  (* Cast the padding array to a list *)
  let pad = Array.to_list pad in
  (* Return the padded message *)
  message @ pad

(* Pads a message M as:
   * M || pad[x](|M|)
   * Padding rule 10*1.
   * The padded message vector will start with the message vector
   * followed by the 10*1 rule to fulfil a length that is a multiple of rate (in bytes)
   * (This means a 1 bit, followed with as many 0s as needed, and a final 1 bit)
*)
let pad_101 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (rate : int) : Circuit.Field.t list =
  let open Circuit in
  (* Find out desired length of the padding in bytes *)
  (* If message is already rate bits, need to pad full rate again *)
  let extra_bytes = bytes_to_pad rate (List.length message) in
  (* 0x01 0x00 ... 0x00 0x80 or 0x81 *)
  let last_field = Common.two_pow (module Circuit) 7 in
  let last = Field.constant @@ last_field in
  (* Create the padding vector *)
  let pad = Array.init extra_bytes ~f:(fun _ -> Field.zero) in
  pad.(0) <- Field.one ;
  pad.(extra_bytes - 1) <- Field.add pad.(extra_bytes - 1) last ;
  (* Cast the padding array to a list *)
  (* Return the padded message *)
  message @ Array.to_list pad

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
  let state_a = state in
  (* XOR the elements of each row together *)
  (* for all x in {0..4}: C[x] = A[x,0] xor A[x,1] xor A[x,2] xor A[x,3] xor A[x,4] *)
  let state_c =
    Array.map state_a ~f:(Array.reduce_exn ~f:(Bitwise.bxor64 (module Circuit)))
  in
  (* for all x in {0..4}: D[x] = C[x-1] xor ROT(C[x+1], 1) *)
  let state_d =
    Array.init keccak_dim ~f:(fun x ->
        Bitwise.(
          bxor64
            (module Circuit)
            (* using (x + m mod m) to avoid negative values *)
            state_c.((x + keccak_dim - 1) mod keccak_dim)
            (rot64 (module Circuit) state_c.((x + 1) mod keccak_dim) 1 Left)) )
  in
  (* for all x in {0..4} and y in {0..4}: E[x,y] = A[x,y] xor D[x] *)
  (* return E *)
  Array.map2_exn state_a state_d ~f:(fun state_a state_d ->
      Array.map state_a ~f:(Bitwise.bxor64 (module Circuit) state_d) )

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
  for x = 0 to keccak_dim - 1 do
    for y = 0 to keccak_dim - 1 do
      (* No need to use module since this is always positive *)
      state_b.(y).(((2 * x) + (3 * y)) mod keccak_dim) <-
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
  for x = 0 to keccak_dim - 1 do
    for y = 0 to keccak_dim - 1 do
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
    (state : Circuit.Field.t State.matrix) (rc : Circuit.Field.t) :
    Circuit.Field.t State.matrix =
  (* Round constants for this round for the iota algorithm *)
  let state_g = state in
  state_g.(0).(0) <- Bitwise.(bxor64 (module Circuit) state_g.(0).(0) rc) ;
  (* Check it is the right round constant is implicit from reusing the right cvar *)
  state_g

(* The round applies the lambda function and then chi and iota
 * It consists of the concatenation of the theta, rho, and pi algorithms.
 * lambda = pi o rho o theta
 * Thus:
 * iota o chi o pi o rho o theta
 *)
let round (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) (rc : Circuit.Field.t) :
    Circuit.Field.t State.matrix =
  let state_a = state in
  let state_e = theta (module Circuit) state_a in
  let state_b = pi_rho (module Circuit) state_e in
  let state_f = chi (module Circuit) state_b in
  let state_d = iota (module Circuit) state_f rc in
  state_d

(* Keccak permutation function with a constant number of rounds *)
let permutation (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) (rc : Circuit.Field.t array) :
    Circuit.Field.t State.matrix =
  for i = 0 to keccak_rounds - 1 do
    let state_i = round (module Circuit) state rc.(i) in
    (* Update state for next step *)
    State.update (module Circuit) ~prev:state ~next:state_i
  done ;
  state

(* Absorb padded message into a keccak state with given rate and capacity *)
let absorb (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (padded_message : Circuit.Field.t list) ~(capacity : int) ~(rate : int)
    ~(rc : Circuit.Field.t array) : Circuit.Field.t State.matrix =
  let open Circuit in
  let root_state = State.zeros (module Circuit) in
  let state = root_state in

  (* split into blocks of rate bits *)
  (* for each block of rate bits in the padded message -> this is rate/8 bytes *)
  let chunks = List.chunks_of padded_message ~length:(rate / 8) in
  (* (capacity / 8) zero bytes *)
  let zeros = Array.to_list @@ Array.create ~len:(capacity / 8) Field.zero in
  for i = 0 to List.length chunks - 1 do
    let block = List.nth_exn chunks i in
    (* pad the block with 0s to up to 1600 bits *)
    let padded_block = block @ zeros in
    (* padded with zeros each block until they are 1600 bit long *)
    assert (List.length padded_block * 8 = keccak_state_length) ;
    let block_state = State.of_bytes (module Circuit) padded_block in
    (* xor the state with the padded block *)
    let state_xor = State.xor (module Circuit) state block_state in
    (* apply the permutation function to the xored state *)
    let state_perm = permutation (module Circuit) state_xor rc in
    State.update (module Circuit) ~prev:state ~next:state_perm
  done ;

  state

(* Squeeze state until it has a desired length in bits *)
let squeeze (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) ~(length : int) ~(rate : int)
    ~(rc : Circuit.Field.t array) : Circuit.Field.t list =
  let copy (bytestring : Circuit.Field.t list)
      (output_array : Circuit.Field.t array) ~(start : int) ~(length : int) =
    for i = 0 to length - 1 do
      output_array.(start + i) <- List.nth_exn bytestring i
    done ;
    ()
  in

  let open Circuit in
  (* bytes per squeeze *)
  let bytes_per_squeeze = rate / 8 in
  (* number of squeezes *)
  let squeezes = (length / rate) + 1 in
  (* multiple of rate that is larger than output_length, in bytes *)
  let output_length = squeezes * bytes_per_squeeze in
  (* array with sufficient space to store the output *)
  let output_array = Array.create ~len:output_length Field.zero in
  (* first state to be squeezed *)
  let bytestring = State.as_prover_to_bytes (module Circuit) state in
  let output_bytes = List.take bytestring bytes_per_squeeze in
  copy output_bytes output_array ~start:0 ~length:bytes_per_squeeze ;
  (* for the rest of squeezes *)
  for i = 1 to squeezes - 1 do
    (* apply the permutation function to the state *)
    let new_state = permutation (module Circuit) state rc in
    State.update (module Circuit) ~prev:state ~next:new_state ;
    (* append the output of the permutation function to the output *)
    let bytestring_i = State.as_prover_to_bytes (module Circuit) state in
    let output_bytes_i = List.take bytestring_i bytes_per_squeeze in
    copy output_bytes_i output_array ~start:(bytes_per_squeeze * i)
      ~length:bytes_per_squeeze ;
    ()
  done ;
  (* Obtain the hash selecting the first bitlength/8 bytes of the output array *)
  let hashed = Array.sub output_array ~pos:0 ~len:(length / 8) in

  Array.to_list hashed

(* Keccak sponge function for 1600 bits of state width
 * Need to split the message into blocks of 1088 bits. 
 *)
let sponge (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (padded_message : Circuit.Field.t list) ~(length : int) ~(capacity : int)
    ~(rate : int) : Circuit.Field.t list =
  let open Circuit in
  (* check that the padded message is a multiple of rate *)
  assert (List.length padded_message * 8 mod rate = 0) ;
  (* setup cvars for round constants *)
  let rc =
    exists (Typ.array ~length:24 Field.typ) ~compute:(fun () ->
        Array.map round_consts ~f:(Common.field_of_hex (module Circuit)) )
  in
  (* absorb *)
  let state = absorb (module Circuit) padded_message ~capacity ~rate ~rc in
  (* squeeze *)
  let hashed = squeeze (module Circuit) state ~length ~rate ~rc in
  hashed

(* Checks in the circuit that a list of cvars are at most 8 bits each *)
let check_bytes (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (inputs : Circuit.Field.t list) : unit =
  let open Circuit in
  (* Create a second list of shifted inputs with 4 more bits*)
  let shifted =
    Core_kernel.List.map ~f:(fun x -> Field.(of_int 16 * x)) inputs
  in
  (* We need to lookup that both the inputs and the shifted values are less than 12 bits *)
  (* Altogether means that it was less than 8 bits *)
  let lookups = inputs @ shifted in
  (* Make sure that a multiple of 3 cvars is in the list *)
  let lookups =
    match List.length lookups % 3 with
    | 2 ->
        lookups @ [ Field.zero ]
    | 1 ->
        lookups @ [ Field.zero; Field.zero ]
    | _ ->
        lookups
  in
  (* We can fit 3 12-bit lookups per row *)
  for i = 0 to (List.length lookups / 3) - 1 do
    Lookup.three_12bit
      (module Circuit)
      (List.nth_exn lookups (3 * i))
      (List.nth_exn lookups ((3 * i) + 1))
      (List.nth_exn lookups ((3 * i) + 2)) ;
    ()
  done ;
  ()

(*
* Keccak hash function with input message passed as list of Cvar bytes.
* The message will be parsed as follows:
* - the first byte of the message will be the least significant byte of the first word of the state (A[0][0])
* - the 10*1 pad will take place after the message, until reaching the bit length rate.
* - then, {0} pad will take place to finish the 1600 bits of the state.
*)
let hash (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(inp_endian = Big) ?(out_endian = Big) ?(byte_checks = false)
    (message : Circuit.Field.t list) ~(length : int) ~(capacity : int)
    (nist_version : bool) : Circuit.Field.t list =
  assert (capacity > 0) ;
  assert (capacity < keccak_state_length) ;
  assert (length > 0) ;
  assert (length mod 8 = 0) ;
  (* Set input to Big Endian format *)
  let message =
    match inp_endian with Big -> message | Little -> List.rev message
  in
  (* Check each cvar input is 8 bits at most if it was not done before at creation time*)
  if byte_checks then check_bytes (module Circuit) message ;
  let rate = keccak_state_length - capacity in
  let padded =
    match nist_version with
    | true ->
        pad_nist (module Circuit) message rate
    | false ->
        pad_101 (module Circuit) message rate
  in
  let hash = sponge (module Circuit) padded ~length ~capacity ~rate in
  (* Check each cvar output is 8 bits at most. Always because they are created here *)
  check_bytes (module Circuit) hash ;
  (* Set input to desired endianness *)
  let hash = match out_endian with Big -> hash | Little -> List.rev hash in
  (* Check each cvar output is 8 bits at most *)
  hash

(* Gagdet for NIST SHA-3 function for output lengths 224/256/384/512.
 * Input and output endianness can be specified. Default is big endian.
 *)
let nist_sha3 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(inp_endian = Big) ?(out_endian = Big) ?(byte_checks = false) (len : int)
    (message : Circuit.Field.t list) : Circuit.Field.t list =
  let hash =
    match len with
    | 224 ->
        hash
          (module Circuit)
          message ~length:224 ~capacity:448 true ~inp_endian ~out_endian
          ~byte_checks
    | 256 ->
        hash
          (module Circuit)
          message ~length:256 ~capacity:512 true ~inp_endian ~out_endian
          ~byte_checks
    | 384 ->
        hash
          (module Circuit)
          message ~length:384 ~capacity:768 true ~inp_endian ~out_endian
          ~byte_checks
    | 512 ->
        hash
          (module Circuit)
          message ~length:512 ~capacity:1024 true ~inp_endian ~out_endian
          ~byte_checks
    | _ ->
        assert false
  in
  hash

(* Gadget for Keccak hash function for the parameters used in Ethereum.
 * Input and output endianness can be specified. Default is big endian.
 *)
let ethereum (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(inp_endian = Big) ?(out_endian = Big) ?(byte_checks = false)
    (message : Circuit.Field.t list) : Circuit.Field.t list =
  hash
    (module Circuit)
    message ~length:256 ~capacity:512 false ~inp_endian ~out_endian ~byte_checks

(* Gagdet for pre-NIST SHA-3 function for output lengths 224/256/384/512.
 * Input and output endianness can be specified. Default is big endian.
 * Note that when calling with output length 256 this is equivalent to the ethereum function 
 *)
let pre_nist (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    ?(inp_endian = Big) ?(out_endian = Big) ?(byte_checks = false) (len : int)
    (message : Circuit.Field.t list) : Circuit.Field.t list =
  match len with
  | 224 ->
      hash
        (module Circuit)
        message ~length:224 ~capacity:448 false ~inp_endian ~out_endian
        ~byte_checks
  | 256 ->
      ethereum (module Circuit) message ~inp_endian ~out_endian ~byte_checks
  | 384 ->
      hash
        (module Circuit)
        message ~length:384 ~capacity:768 false ~inp_endian ~out_endian
        ~byte_checks
  | 512 ->
      hash
        (module Circuit)
        message ~length:512 ~capacity:1024 false ~inp_endian ~out_endian
        ~byte_checks
  | _ ->
      assert false

(* KECCAK GADGET TESTS *)

let%test_unit "keccak gadget" =
  if tests_enabled then (
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    let test_keccak ?cs ?inp_endian ?out_endian ~nist ~len message expected =
      let cs, _proof_keypair, _proof =
        Runner.generate_and_verify_proof ?cs (fun () ->
            let open Runner.Impl in
            assert (String.length message % 2 = 0) ;
            let message =
              Array.to_list
              @@ exists
                   (Typ.array ~length:(String.length message / 2) Field.typ)
                   ~compute:(fun () ->
                     Array.of_list
                     @@ Common.field_bytes_of_hex (module Runner.Impl) message
                     )
            in
            let hashed =
              Array.of_list
              @@
              match nist with
              | true ->
                  nist_sha3
                    (module Runner.Impl)
                    len message ?inp_endian ?out_endian ~byte_checks:true
              | false ->
                  pre_nist
                    (module Runner.Impl)
                    len message ?inp_endian ?out_endian ~byte_checks:true
            in

            let expected =
              Array.of_list
              @@ Common.field_bytes_of_hex (module Runner.Impl) expected
            in
            (* Check expected hash output *)
            as_prover (fun () ->
                for i = 0 to Array.length hashed - 1 do
                  let byte_hash =
                    Common.cvar_field_to_bignum_bigint_as_prover
                      (module Runner.Impl)
                      hashed.(i)
                  in
                  let byte_exp =
                    Common.field_to_bignum_bigint
                      (module Runner.Impl)
                      expected.(i)
                  in
                  assert (Bignum_bigint.(byte_hash = byte_exp))
                done ;
                () ) ;
            () )
      in
      cs
    in

    (* Positive tests *)
    let cs_eth256_1byte =
      test_keccak ~nist:false ~len:256 "30"
        "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d"
    in

    let cs_nist512_1byte =
      test_keccak ~nist:true ~len:512 "30"
        "2d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c"
    in

    (* I am the owner of the NFT with id X on the Ethereum chain *)
    let _cs =
      test_keccak ~nist:false ~len:256
        "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e"
        "63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36"
    in
    let _cs =
      test_keccak ~nist:false ~len:512
        "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e"
        "848cf716c2d64444d2049f215326b44c25a007127d2871c1b6004a9c3d102f637f31acb4501e59f3a0160066c8814816f4dc58a869f37f740e09b9a8757fa259"
    in

    (* The following two tests use 2 blocks instead *)
    (* For Keccak *)
    let _cs =
      test_keccak ~nist:false ~len:256
        "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116df9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e42d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36"
        "560deb1d387f72dba729f0bd0231ad45998dda4b53951645322cf95c7b6261d9"
    in
    (* For NIST *)
    let _cs =
      test_keccak ~nist:true ~len:256
        "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116df9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e42d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36"
        "1784354c4bbfa5f54e5db23041089e65a807a7b970e3cfdba95e2fbe63b1c0e4"
    in

    (* Padding of input 1080 bits and 1088 bits *)
    (* 135 bits, uses the following single padding byte as 0x81 *)
    let cs135 =
      test_keccak ~nist:false ~len:256
        "391ccf9b5de23bb86ec6b2b142adb6e9ba6bee8519e7502fb8be8959fbd2672934cc3e13b7b45bf2b8a5cb48881790a7438b4a326a0c762e31280711e6b64fcc2e3e4e631e501d398861172ea98603618b8f23b91d0208b0b992dfe7fdb298b6465adafbd45e4f88ee9dc94e06bc4232be91587f78572c169d4de4d8b95b714ea62f1fbf3c67a4"
        "7d5655391ede9ca2945f32ad9696f464be8004389151ce444c89f688278f2e1d"
    in

    (* 136 bits, 2 blocks and second is just padding *)
    let cs136 =
      test_keccak ~nist:false ~len:256
        "ff391ccf9b5de23bb86ec6b2b142adb6e9ba6bee8519e7502fb8be8959fbd2672934cc3e13b7b45bf2b8a5cb48881790a7438b4a326a0c762e31280711e6b64fcc2e3e4e631e501d398861172ea98603618b8f23b91d0208b0b992dfe7fdb298b6465adafbd45e4f88ee9dc94e06bc4232be91587f78572c169d4de4d8b95b714ea62f1fbf3c67a4"
        "37694fd4ba137be747eb25a85b259af5563e0a7a3010d42bd15963ac631b9d3f"
    in

    (* Input already looks like padded *)
    let _cs =
      test_keccak ~cs:cs135 ~nist:false ~len:256
        "800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"
        "0edbbae289596c7da9fafe65931c5dce3439fb487b8286d6c1970e44eea39feb"
    in

    let _cs =
      test_keccak ~cs:cs136 ~nist:false ~len:256
        "80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"
        "bbf1f49a2cc5678aa62196d0c3108d89425b81780e1e90bcec03b4fb5f834714"
    in

    (* Reusing *)
    let _cs =
      test_keccak ~cs:cs_eth256_1byte ~nist:false ~len:256 "00"
        "bc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a"
    in

    let cs2 =
      test_keccak ~nist:false ~len:256 "a2c0"
        "9856642c690c036527b8274db1b6f58c0429a88d9f3b9298597645991f4f58f0"
    in

    let _cs =
      test_keccak ~cs:cs2 ~nist:false ~len:256 "0a2c"
        "295b48ad49eff61c3abfd399c672232434d89a4ef3ca763b9dbebb60dbb32a8b"
    in

    (* Endianness *)
    let _cs =
      test_keccak ~nist:false ~len:256 ~inp_endian:Little ~out_endian:Little
        "2c0a"
        "8b2ab3db60bbbe9d3b76caf34e9ad834242372c699d3bf3a1cf6ef49ad485b29"
    in

    (* Negative tests *)
    (* Check cannot use bad hex inputs *)
    assert (
      Common.is_error (fun () ->
          test_keccak ~nist:false ~len:256 "a2c"
            "07f02d241eeba9c909a1be75e08d9e8ac3e61d9e24fa452a6785083e1527c467" ) ) ;

    (* Check cannot use bad hex inputs *)
    assert (
      Common.is_error (fun () ->
          test_keccak ~nist:true ~len:256 "0"
            "f39f4526920bb4c096e5722d64161ea0eb6dbd0b4ff0d812f31d56fb96142084" ) ) ;

    (* Cannot reuse CS for different output length *)
    assert (
      Common.is_error (fun () ->
          test_keccak ~cs:cs_nist512_1byte ~nist:true ~len:256 "30"
            "f9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e4" ) ) ;

    (* Checking cannot reuse CS for same length but different padding *)
    assert (
      Common.is_error (fun () ->
          test_keccak ~cs:cs_eth256_1byte ~nist:true ~len:256
            "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e"
            "63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36" ) ) ;

    (* Cannot reuse cs with different endianness *)
    assert (
      Common.is_error (fun () ->
          test_keccak ~cs:cs2 ~nist:false ~len:256 ~inp_endian:Little
            ~out_endian:Little "2c0a"
            "8b2ab3db60bbbe9d3b76caf34e9ad834242372c699d3bf3a1cf6ef49ad485b29" ) ) ;

    () ) ;

  ()
