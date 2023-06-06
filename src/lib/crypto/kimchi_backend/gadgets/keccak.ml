open Core_kernel
module Bignum_bigint = Snarky_backendless.Backend_extended.Bignum_bigint
module Snark_intf = Snarky_backendless.Snark_intf

open Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint

let tests_enabled = true

(* DEFINITIONS OF CONSTANTS FOR KECCAK *)

(* Length of the square matrix side of Keccak states *)
let keccak_dim = 5

(* value `l` in Keccak, ranges from 0 to 6 (7 possible values) *)
let keccak_ell = 6

(* width of the lane of the state, meaning the length of each word in bits (64) *)
let keccak_word = Int.pow 2 keccak_ell

(* length of the state in bits, meaning the 5x5 matrix of words in bits (1600) *)
let keccak_state_length = Int.pow keccak_dim 2 * keccak_word

(* number of rounds of the Keccak permutation function depending on the value `l` (24) *)
(*let keccak_rounds = 12 + (2 * keccak_ell)*)
let keccak_rounds = 24

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
    for y = 0 to keccak_dim - 1 do
      for x = 0 to keccak_dim - 1 do
        prev.(x).(y) <- next.(x).(y)
      done
    done

  (* Converts a list of bytes to a matrix of Field elements *)
  let of_bytes (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (bytestring : Circuit.Field.t list) : Circuit.Field.t matrix =
    let open Circuit in
    assert (List.length bytestring = 200) ;
    let state =
      Array.make_matrix ~dimx:keccak_dim ~dimy:keccak_dim Field.zero
    in
    for y = 0 to keccak_dim - 1 do
      for x = 0 to keccak_dim - 1 do
        for z = 0 to (keccak_word / 8) - 1 do
          let index = (8 * ((keccak_dim * y) + x)) + z in
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

  (* Converts a state of cvars to a list of bytes as cvars *)
  let as_prover_to_bytes (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (state : Circuit.Field.t matrix) : Circuit.Field.t list =
    let open Circuit in
    assert (
      Array.length state = keccak_dim && Array.length state.(0) = keccak_dim ) ;
    let bytestring = Array.create ~len:200 Field.zero in
    let bytes_per_word = keccak_word / 8 in
    for y = 0 to keccak_dim - 1 do
      for x = 0 to keccak_dim - 1 do
        let base_index = bytes_per_word * ((keccak_dim * y) + x) in
        for z = 0 to bytes_per_word - 1 do
          let index = base_index + z in
          let byte =
            exists Field.typ ~compute:(fun () ->
                let word =
                  Common.cvar_field_to_bignum_bigint_as_prover
                    (module Circuit)
                    state.(x).(y)
                in
                let power_lo = 8 * z in
                let offset_lo =
                  Bignum_bigint.(pow (of_int 2) (of_int power_lo))
                in
                let two_pow_8 = Bignum_bigint.(pow (of_int 2) (of_int 8)) in
                let byte =
                  Bignum_bigint.(
                    (word - (word % offset_lo)) / offset_lo % two_pow_8)
                in
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
    assert (
      Array.length input1 = keccak_dim && Array.length input1.(0) = keccak_dim ) ;
    assert (
      Array.length input2 = keccak_dim && Array.length input2.(0) = keccak_dim ) ;
    let output =
      Array.make_matrix ~dimx:keccak_dim ~dimy:keccak_dim Field.zero
    in
    for y = 0 to keccak_dim - 1 do
      for x = 0 to keccak_dim - 1 do
        output.(x).(y) <-
          Bitwise.bxor64 (module Circuit) input1.(x).(y) input2.(x).(y)
      done
    done ;
    output

  let _print (type f)
      (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
      (state : Circuit.Field.t matrix) =
    let open Circuit in
    as_prover (fun () ->
        for x = 0 to keccak_dim - 1 do
          for y = 0 to keccak_dim - 1 do
            let _elem =
              Common.cvar_field_to_bignum_bigint_as_prover
                (module Circuit)
                state.(x).(y)
            in
            ()
          done
        done )
end

(* KECCAK HASH FUNCTION IMPLEMENTATION *)

(* Performs the modulo operation, not remainder as in mod which instead computes integer remainder *)
let modulo (x : int) (m : int) : int = ((x mod m) + m) mod m

(* Pads a message M as:
   * M || pad[x](|M|)
   * Padding rule 0x06 ..0*..1.
   * The padded message vector will start with the message vector
   * followed by the 0*1 rule to fulfil a length that is a multiple of rate (in bytes)
*)
let pad_nist (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (rate : int) : Circuit.Field.t list =
  let open Circuit in
  (* Find out desired length of the padding in bytes *)
  (* If message is already rate bits, need to pad full rate again *)
  let extra_bytes = (rate / 8) - (List.length message mod rate) in
  (* 0x06 0x00 ... 0x00 0x80 or 0x86 *)
  let last_field = Common.two_pow (module Circuit) 7 in
  let last = Field.constant @@ Common.two_pow (module Circuit) 7 in
  (* Create the padding vector *)
  let pad = Array.create ~len:extra_bytes Field.zero in
  pad.(0) <- Field.of_int 6 ;
  pad.(extra_bytes - 1) <- Field.add pad.(extra_bytes - 1) last ;
  Field.Assert.equal (Field.constant last_field) last ;
  (* Cast the padding array to a list *)
  let pad = Array.to_list pad in
  (* Return the padded message *)
  message @ pad

(* Pads a message M as:
   * M || pad[x](|M|)
   * Padding rule 10*1.
   * The padded message vector will start with the message vector
   * followed by the 10*1 rule to fulfil a length that is a multiple of rate (in bytes)
*)
let pad_101 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) (rate : int) : Circuit.Field.t list =
  let open Circuit in
  (* Find out desired length of the padding in bytes *)
  (* If message is already rate bits, need to pad full rate again *)
  let extra_bytes = (rate / 8) - (List.length message mod rate) in
  (* 0x01 0x00 ... 0x00 0x80 or 0x81 *)
  let last_field = Common.two_pow (module Circuit) 7 in
  let last = Field.constant @@ last_field in
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
  for x = 0 to keccak_dim - 1 do
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
  for x = 0 to keccak_dim - 1 do
    state_d.(x) <-
      Bitwise.(
        bxor64
          (module Circuit)
          state_c.(modulo (x - 1) keccak_dim)
          (rot64 (module Circuit) state_c.((x + 1) mod keccak_dim) 1 Left)) ;
    (* for all x in {0..4} and y in {0..4}: E[x,y] = A[x,y] xor D[x] *)
    for y = 0 to keccak_dim - 1 do
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
    (state : Circuit.Field.t State.matrix) (round : int) :
    Circuit.Field.t State.matrix =
  let open Circuit in
  (* Round constants for this round for the iota algorithm *)
  let rc =
    exists Field.typ ~compute:(fun () ->
        Common.field_of_hex (module Circuit) round_consts.(round) )
  in
  let state_g = state in
  state_g.(0).(0) <- Bitwise.(bxor64 (module Circuit) state_g.(0).(0) rc) ;
  (* Check it is the right round constant *)
  Field.Assert.equal rc
    (Field.constant (Common.field_of_hex (module Circuit) round_consts.(round))) ;
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

(* Keccak permutation function with a constant number of rounds *)
let permutation (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) : Circuit.Field.t State.matrix =
  for i = 0 to keccak_rounds - 1 do
    let state_i = round (module Circuit) state i in
    (* Update state for next step *)
    State.update (module Circuit) ~prev:state ~next:state_i
  done ;
  state

(* Absorb padded message into a keccak state with given rate and capacity *)
let absorb (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (padded_message : Circuit.Field.t list) ~(capacity : int) ~(rate : int) :
    Circuit.Field.t State.matrix =
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
    let state_perm = permutation (module Circuit) state_xor in
    State.update (module Circuit) ~prev:state ~next:state_perm
  done ;

  state

(* Squeeze state until it has a desired length in bits *)
let squeeze (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (state : Circuit.Field.t State.matrix) ~(length : int) ~(rate : int) :
    Circuit.Field.t list =
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
    let new_state = permutation (module Circuit) state in
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
  (* check that the padded message is a multiple of rate *)
  assert (List.length padded_message * 8 mod rate = 0) ;

  (* absorb *)
  let state = absorb (module Circuit) padded_message ~capacity ~rate in
  (* squeeze *)
  let hashed = squeeze (module Circuit) state ~length ~rate in
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
        lookups @ [ Field.zero ] @ [ Field.zero ]
    | 1 ->
        lookups @ [ Field.zero ]
    | _ ->
        lookups
  in
  (* We can fit 3 12-bit lookups per row *)
  for i = 0 to (List.length lookups / 3) - 1 do
    with_label "lookup_byte" (fun () ->
        assert_
          { annotation = Some __LOC__
          ; basic =
              Kimchi_backend_common.Plonk_constraint_system.Plonk_constraint.T
                (Lookup
                   { w0 = Field.one
                   ; w1 = List.nth_exn lookups (3 * i)
                   ; w2 = Field.zero
                   ; w3 = List.nth_exn lookups ((3 * i) + 1)
                   ; w4 = Field.zero
                   ; w5 = List.nth_exn lookups ((3 * i) + 2)
                   ; w6 = Field.zero
                   } )
          } ) ;
    ()
  done ;
  ()

(*
* Keccak hash function with input message passed as list of 1byte Cvars.
* The message will be parsed as follows:
* - the first byte of the message will be the least significant byte of the first word of the state (A[0][0])
* - the 10*1 pad will take place after the message, until reaching the bit length rate.
* - then, {0} pad will take place to finish the 1600 bits of the state.
*)
let hash (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) ~(length : int) ~(capacity : int)
    (nist : bool) : Circuit.Field.t list =
  assert (capacity > 0) ;
  assert (length > 0) ;
  assert (length mod 8 = 0) ;
  (* Check each cvar input is 8 bits at most *)
  check_bytes (module Circuit) message ;
  let rate = keccak_state_length - capacity in
  let padded =
    match nist with
    | true ->
        pad_nist (module Circuit) message rate
    | false ->
        pad_101 (module Circuit) message rate
  in
  let hash = sponge (module Circuit) padded ~length ~capacity ~rate in
  check_bytes (module Circuit) hash ;
  (* Check each cvar output is 8 bits at most *)
  hash

(* Gagdet for NIST SHA-3 function for output lengths 224/256/384/512 *)
let nist_sha3 (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (len : int) (message : Circuit.Field.t list) : Circuit.Field.t array =
  let hash =
    match len with
    | 224 ->
        hash (module Circuit) message ~length:224 ~capacity:448 true
    | 256 ->
        hash (module Circuit) message ~length:256 ~capacity:512 true
    | 384 ->
        hash (module Circuit) message ~length:384 ~capacity:768 true
    | 512 ->
        hash (module Circuit) message ~length:512 ~capacity:1024 true
    | _ ->
        assert false
  in
  Array.of_list hash

(* Gadget for Keccak hash function for the parameters used in Ethereum *)
let eth_keccak (type f)
    (module Circuit : Snarky_backendless.Snark_intf.Run with type field = f)
    (message : Circuit.Field.t list) : Circuit.Field.t array =
  Array.of_list @@ hash (module Circuit) message ~length:256 ~capacity:512 false

(* KECCAK GADGET TESTS *)

let%test_unit "keccak gadget" =
  ( if tests_enabled then
    let (* Import the gadget test runner *)
    open Kimchi_gadgets_test_runner in
    (* Initialize the SRS cache. *)
    let () =
      try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()
    in

    let test_keccak ?cs ~nist ~len message expected =
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
              match nist with
              | true ->
                  nist_sha3 (module Runner.Impl) len message
              | false ->
                  eth_keccak (module Runner.Impl) message
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
    let _cs =
      test_keccak ~nist:false ~len:256 "30"
        "044852b2a670ade5407e78fb2863c51de9fcb96542a07186fe3aeda6bb8a116d"
    in
    let _cs =
      test_keccak ~nist:true ~len:256 "30"
        "f9e2eaaa42d9fe9e558a9b8ef1bf366f190aacaa83bad2641ee106e9041096e4"
    in
    let _cs =
      test_keccak ~nist:true ~len:512 "30"
        "2d44da53f305ab94b6365837b9803627ab098c41a6013694f9b468bccb9c13e95b3900365eb58924de7158a54467e984efcfdabdbcc9af9a940d49c51455b04c"
    in
    (* I am the owner of the NFT with id X on the Ethereum chain *)
    let _cs = test_keccak ~nist:false ~len:256 "4920616d20746865206f776e6572206f6620746865204e465420776974682069642058206f6e2074686520457468657265756d20636861696e" "63858e0487687c3eeb30796a3e9307680e1b81b860b01c88ff74545c2c314e36" in

    () ) ;

  ()
