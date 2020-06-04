open Core_kernel

module Digit = struct
  (* A number between 0 and 15 *)
  type t =
    | H0
    | H1
    | H2
    | H3
    | H4
    | H5
    | H6
    | H7
    | H8
    | H9
    | H10
    | H11
    | H12
    | H13
    | H14
    | H15

  let of_char_exn c =
    match Char.lowercase c with
    | '0' ->
        H0
    | '1' ->
        H1
    | '2' ->
        H2
    | '3' ->
        H3
    | '4' ->
        H4
    | '5' ->
        H5
    | '6' ->
        H6
    | '7' ->
        H7
    | '8' ->
        H8
    | '9' ->
        H9
    | 'a' ->
        H10
    | 'b' ->
        H11
    | 'c' ->
        H12
    | 'd' ->
        H13
    | 'e' ->
        H14
    | 'f' ->
        H15
    | _ ->
        failwithf "bad hex digit %c" c ()

  let to_int = function
    | H0 ->
        0
    | H1 ->
        1
    | H2 ->
        2
    | H3 ->
        3
    | H4 ->
        4
    | H5 ->
        5
    | H6 ->
        6
    | H7 ->
        7
    | H8 ->
        8
    | H9 ->
        9
    | H10 ->
        10
    | H11 ->
        11
    | H12 ->
        12
    | H13 ->
        13
    | H14 ->
        14
    | H15 ->
        15
end

let hex_char_of_int_exn = function
  | 0 ->
      '0'
  | 1 ->
      '1'
  | 2 ->
      '2'
  | 3 ->
      '3'
  | 4 ->
      '4'
  | 5 ->
      '5'
  | 6 ->
      '6'
  | 7 ->
      '7'
  | 8 ->
      '8'
  | 9 ->
      '9'
  | 10 ->
      'a'
  | 11 ->
      'b'
  | 12 ->
      'c'
  | 13 ->
      'd'
  | 14 ->
      'e'
  | 15 ->
      'f'
  | d ->
      failwithf "bad hex digit %d" d ()

module Sequence_be = struct
  type t = Digit.t array

  let decode ?(pos = 0) s =
    let n = String.length s - pos in
    Array.init n ~f:(fun i -> Digit.of_char_exn s.[pos + i])

  let to_bytes_like ~init (t : t) =
    let n = Array.length t in
    let k = n / 2 in
    assert (n = k + k) ;
    init k ~f:(fun i ->
        Char.of_int_exn
          ((16 * Digit.to_int t.(2 * i)) + Digit.to_int t.((2 * i) + 1)) )

  let to_string = to_bytes_like ~init:String.init

  let to_bytes = to_bytes_like ~init:Bytes.init

  let to_bigstring = to_bytes_like ~init:Bigstring.init
end

let decode ?(pos = 0) ~init t =
  let n = String.length t - pos in
  let k = n / 2 in
  assert (n = k + k) ;
  let h j = Digit.(to_int (of_char_exn t.[pos + j])) in
  init k ~f:(fun i -> Char.of_int_exn ((16 * h (2 * i)) + h ((2 * i) + 1)))

let encode t =
  String.init
    (2 * String.length t)
    ~f:(fun i ->
      let c = Char.to_int t.[i / 2] in
      let c = if i mod 2 = 0 then (* hi *)
                c lsr 4 else (* lo *)
                          c in
      hex_char_of_int_exn (c land 15) )

let%test_unit "decode" =
  let t = String.init 100 ~f:(fun _ -> Char.of_int_exn (Random.int 256)) in
  let h = encode t in
  assert (String.equal t (decode ~init:String.init h)) ;
  assert (String.equal t Sequence_be.(to_string (decode h)))
