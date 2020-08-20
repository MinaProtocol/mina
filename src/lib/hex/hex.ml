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

(* TODO: Better deduplicate the hex coding between these two implementations #5711 *)
module Safe = struct
  (** to_hex : {0x0-0xff}* -> [A-F0-9]* *)
  let to_hex (data : string) : string =
    String.to_list data
    |> List.map ~f:(fun c ->
           let charify u4 =
             match u4 with
             | x when x <= 9 && x >= 0 ->
                 Char.(of_int_exn @@ (x + to_int '0'))
             | x when x <= 15 && x >= 10 ->
                 Char.(of_int_exn @@ (x - 10 + to_int 'A'))
             | _ ->
                 failwith "Unexpected u4 has only 4bits of information"
           in
           let high = charify @@ ((Char.to_int c land 0xF0) lsr 4) in
           let lo = charify (Char.to_int c land 0x0F) in
           String.of_char_list [high; lo] )
    |> String.concat

  let%test_unit "to_hex sane" =
    let start = "a" in
    let hexified = to_hex start in
    let expected = "61" in
    if String.equal expected hexified then ()
    else
      failwithf "start: %s ; hexified : %s ; expected: %s" start hexified
        expected ()

  (** of_hex : [a-fA-F0-9]* -> {0x0-0xff}* option *)
  let of_hex (hex : string) : string option =
    let to_u4 c =
      let open Char in
      assert (is_alphanum c) ;
      match c with
      | _ when is_digit c ->
          to_int c - to_int '0'
      | _ when is_uppercase c ->
          to_int c - to_int 'A' + 10
      | _ (* when is_alpha *) ->
          to_int c - to_int 'a' + 10
    in
    String.to_list hex |> List.chunks_of ~length:2
    |> List.fold_result ~init:[] ~f:(fun acc chunk ->
           match chunk with
           | [a; b] when Char.is_alphanum a && Char.is_alphanum b ->
               Or_error.return
               @@ (Char.((to_u4 a lsl 4) lor to_u4 b |> of_int_exn) :: acc)
           | _ ->
               Or_error.error_string "invalid hex" )
    |> Or_error.ok
    |> Option.map ~f:(Fn.compose String.of_char_list List.rev)

  let%test_unit "partial isomorphism" =
    Quickcheck.test ~sexp_of:[%sexp_of: string] ~examples:["\243"; "abc"]
      Quickcheck.Generator.(map (list char) ~f:String.of_char_list)
      ~f:(fun s ->
        let hexified = to_hex s in
        let actual = Option.value_exn (of_hex hexified) in
        let expected = s in
        if String.equal actual expected then ()
        else
          failwithf
            !"expected: %s ; hexified: %s ; actual: %s"
            expected hexified actual () )
end
