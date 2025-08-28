open Core_kernel

module Chunked = struct
  (** The input for a random oracle, formed of full field elements and 'chunks'
      of fields that can be combined together into one or more field elements.

      The chunks are represented as [(field, length)], where
      [0 <= field < 2^length]. This allows us to efficiently combine values in
      a known range. For example,
{[
    { field_elements= [||]; packeds= [|(x, 64); (y, 32); (z, 16)|] }
]}
      results in the chunks being combined as [x * 2^(32+16) + y * 2^(64) + z].
      When the chunks do not fit within a single field element, they are
      greedily concatenated to form field elements, from left to right.
      This packing is performed by the [pack_to_fields] helper function.
  *)
  type 'field t =
    { field_elements : 'field array; packeds : ('field * int) array }
  [@@deriving sexp, compare]

  let append (t1 : _ t) (t2 : _ t) =
    { field_elements = Array.append t1.field_elements t2.field_elements
    ; packeds = Array.append t1.packeds t2.packeds
    }

  let field_elements (a : 'f array) : 'f t =
    { field_elements = a; packeds = [||] }

  let field x : _ t = field_elements [| x |]

  (** An input [[|(x_1, l_1); (x_2, l_2); ...|]] includes the values
      [[|x_1; x_2; ...|]] in the input, assuming that `0 <= x_1 < 2^l_1`,
      `0 <= x_2 < 2^l_2`, etc. so that multiple [x_i]s can be combined into a
      single field element when the sum of their [l_i]s are less than the size
      of the field modulus (in bits).
  *)
  let packeds a = { field_elements = [||]; packeds = a }

  (** [packed x = packeds [| x |]] *)
  let packed xn : _ t = packeds [| xn |]

  module type Field_intf = sig
    type t

    val size_in_bits : int

    val zero : t

    val ( + ) : t -> t -> t

    val ( * ) : t -> t -> t
  end

  (** Convert the input into a series of field elements, by concatenating
      any chunks of input that fit into a single field element.
      The concatenation is greedy, operating from left to right.
  *)
  let pack_to_fields (type t) (module F : Field_intf with type t = t)
      ~(pow2 : int -> t) { field_elements; packeds } =
    let shift_left acc n = F.( * ) acc (pow2 n) in
    let open F in
    let packed_bits =
      let xs, acc, acc_n =
        Array.fold packeds ~init:([], zero, 0)
          ~f:(fun (xs, acc, acc_n) (x, n) ->
            let n' = Int.(n + acc_n) in
            if Int.(n' < size_in_bits) then (xs, shift_left acc n + x, n')
            else (acc :: xs, x, n) )
      in
      (* if acc_n = 0, packeds was empty (or acc holds 0 bits) and we don't want to append 0 *)
      let xs = if acc_n > 0 then acc :: xs else xs in
      Array.of_list_rev xs
    in
    Array.append field_elements packed_bits
end

module Legacy = struct
  type ('field, 'bool) t =
    { field_elements : 'field array; bitstrings : 'bool list array }
  [@@deriving sexp, compare]

  let append t1 t2 =
    { field_elements = Array.append t1.field_elements t2.field_elements
    ; bitstrings = Array.append t1.bitstrings t2.bitstrings
    }

  let field_elements x = { field_elements = x; bitstrings = [||] }

  let field x = { field_elements = [| x |]; bitstrings = [||] }

  let bitstring x = { field_elements = [||]; bitstrings = [| x |] }

  let bitstrings x = { field_elements = [||]; bitstrings = x }

  let pack_bits ~max_size ~pack { field_elements = _; bitstrings } =
    let rec pack_full_fields rev_fields bits length =
      if length >= max_size then
        let field_bits, bits = List.split_n bits max_size in
        pack_full_fields (pack field_bits :: rev_fields) bits (length - max_size)
      else (rev_fields, bits, length)
    in
    let packed_field_elements, remaining_bits, remaining_length =
      Array.fold bitstrings ~init:([], [], 0)
        ~f:(fun (acc, bits, n) bitstring ->
          let n = n + List.length bitstring in
          let bits = bits @ bitstring in
          let acc, bits, n = pack_full_fields acc bits n in
          (acc, bits, n) )
    in
    if remaining_length = 0 then packed_field_elements
    else pack remaining_bits :: packed_field_elements

  let pack_to_fields ~size_in_bits ~pack { field_elements; bitstrings } =
    let max_size = size_in_bits - 1 in
    let packed_bits =
      pack_bits ~max_size ~pack { field_elements; bitstrings }
    in
    Array.append field_elements (Array.of_list_rev packed_bits)

  let to_bits ~unpack { field_elements; bitstrings } =
    let field_bits = Array.map ~f:unpack field_elements in
    List.concat @@ Array.to_list @@ Array.append field_bits bitstrings

  module Coding = struct
    (** See https://github.com/CodaProtocol/coda/blob/develop/rfcs/0038-rosetta-construction-api.md for details on schema *)

    (** Serialize a random oracle input with 32byte fields into bytes according to the RFC0038 specification *)
    let serialize ~string_of_field ~to_bool ~of_bool t =
      let len_to_string x =
        String.of_char_list
          Char.
            [ of_int_exn @@ ((x lsr 24) land 0xff)
            ; of_int_exn @@ ((x lsr 16) land 0xff)
            ; of_int_exn @@ ((x lsr 8) land 0xff)
            ; of_int_exn @@ (x land 0xff)
            ]
      in
      let len1 = len_to_string @@ Array.length t.field_elements in
      let fields =
        (* We only support 32byte fields *)
        let () =
          if Array.length t.field_elements > 0 then
            assert (String.length (string_of_field t.field_elements.(0)) = 32)
          else ()
        in
        Array.map t.field_elements ~f:string_of_field |> String.concat_array
      in
      let len2 =
        len_to_string
        @@ Array.sum (module Int) t.bitstrings ~f:(fun x -> List.length x)
      in
      let packed =
        pack_bits t ~max_size:8 ~pack:(fun bs ->
            let rec go i acc = function
              | [] ->
                  acc
              | b :: bs ->
                  go (i + 1) ((acc * 2) + if to_bool b then 1 else 0) bs
            in
            let pad =
              List.init (8 - List.length bs) ~f:(Fn.const (of_bool false))
            in
            let combined = bs @ pad in
            assert (List.length combined = 8) ;
            go 0 0 combined )
        |> List.map ~f:Char.of_int_exn
        |> List.rev |> String.of_char_list
      in
      len1 ^ fields ^ len2 ^ packed

    module Parser = struct
      (* TODO: Before using this too much; use a solid parser library instead or beef this one up with more debugging info *)

      (* The parser is a function over this monad-fail *)
      module M = Result

      module T = struct
        type ('a, 'e) t = char list -> ('a * char list, 'e) M.t

        let return a cs = M.return (a, cs)

        let bind : ('a, 'e) t -> f:('a -> ('b, 'e) t) -> ('b, 'e) t =
         fun t ~f cs ->
          let open M.Let_syntax in
          let%bind a, rest = t cs in
          f a rest

        let map = `Define_using_bind
      end

      include Monad.Make2 (T)

      let run p cs =
        p cs
        |> M.bind ~f:(fun (a, cs') ->
               match cs' with [] -> M.return a | _ -> M.fail `Expected_eof )

      let fail why _ = M.fail why

      let char c = function
        | c' :: cs when Char.equal c c' ->
            M.return (c', cs)
        | c' :: _ ->
            M.fail (`Unexpected_char c')
        | [] ->
            M.fail `Unexpected_eof

      let u8 = function
        | c :: cs ->
            M.return (c, cs)
        | [] ->
            M.fail `Unexpected_eof

      let u32 =
        let open Let_syntax in
        let open Char in
        let%map a = u8 and b = u8 and c = u8 and d = u8 in
        (to_int a lsl 24)
        lor (to_int b lsl 16)
        lor (to_int c lsl 8)
        lor to_int d

      let eof = function [] -> M.return ((), []) | _ -> M.fail `Expected_eof

      let take n cs =
        if List.length cs < n then M.fail `Unexpected_eof
        else M.return (List.split_n cs n)

      (** p zero or more times, never fails *)
      let many p =
        (fun cs ->
          let rec go xs acc =
            match p xs with
            | Ok (a, xs) ->
                go xs (a :: acc)
            | Error _ ->
                (acc, xs)
          in
          M.return @@ go cs [] )
        |> map ~f:List.rev

      (** p exactly n times *)
      let exactly n p =
        (fun cs ->
          let rec go xs acc = function
            | 0 ->
                M.return (acc, xs)
            | i ->
                let open M.Let_syntax in
                let%bind a, xs = p xs in
                go xs (a :: acc) (i - 1)
          in
          go cs [] n )
        |> map ~f:List.rev

      let return_res r cs = r |> Result.map ~f:(fun x -> (x, cs))
    end

    let bits_of_byte ~of_bool b =
      let b = Char.to_int b in
      let f x =
        of_bool
          ( match x with
          | 0 ->
              false
          | 1 ->
              true
          | _ ->
              failwith "Unexpected boolean integer" )
      in
      [ (b land (0x1 lsl 7)) lsr 7
      ; (b land (0x1 lsl 6)) lsr 6
      ; (b land (0x1 lsl 5)) lsr 5
      ; (b land (0x1 lsl 4)) lsr 4
      ; (b land (0x1 lsl 3)) lsr 3
      ; (b land (0x1 lsl 2)) lsr 2
      ; (b land (0x1 lsl 1)) lsr 1
      ; b land 0x1
      ]
      |> List.map ~f

    (** Deserialize bytes into a random oracle input with 32byte fields according to the RFC0038 specification *)
    let deserialize ~field_of_string ~of_bool s =
      let field =
        let open Parser.Let_syntax in
        let%bind u8x32 = Parser.take 32 in
        let s = String.of_char_list u8x32 in
        Parser.return_res (field_of_string s)
      in
      let parser =
        let open Parser.Let_syntax in
        let%bind len1 = Parser.u32 in
        let%bind fields = Parser.exactly len1 field in
        let%bind len2 = Parser.u32 in
        let%map bytes = Parser.(many u8) in
        let bits = List.concat_map ~f:(bits_of_byte ~of_bool) bytes in
        let bitstring = List.take bits len2 in
        { field_elements = Array.of_list fields; bitstrings = [| bitstring |] }
      in
      Parser.run parser s

    (** String of field as bits *)
    let string_of_field xs =
      List.chunks_of xs ~length:8
      |> List.map ~f:(fun xs ->
             let rec go i acc = function
               | [] ->
                   acc
               | b :: bs ->
                   go (i + 1) ((acc * 2) + if b then 1 else 0) bs
             in
             let pad = List.init (8 - List.length xs) ~f:(Fn.const false) in
             let combined = xs @ pad in
             assert (List.length combined = 8) ;
             go 0 0 combined )
      |> List.map ~f:Char.of_int_exn
      |> String.of_char_list

    (** Field of string as bits *)
    let field_of_string s ~size_in_bits =
      List.concat_map (String.to_list s) ~f:(bits_of_byte ~of_bool:Fn.id)
      |> Fn.flip List.take size_in_bits
      |> Result.return
  end

  (** Coding2 is an alternate binary coding setup where we pass two arrays of
 *  field elements instead of a single structure to simplify manipulation
 *  outside of the Mina construction API
 *
 * This is described as the second mechanism for coding Random_oracle_input in
 * RFC0038
 *
*)
  module Coding2 = struct
    module Rendered = struct
      (* as bytes, you must hex this later *)
      type 'field t_ = { prefix : 'field array; suffix : 'field array }
      [@@deriving yojson]

      type t = string t_ [@@deriving yojson]

      let map ~f { prefix; suffix } =
        { prefix = Array.map ~f prefix; suffix = Array.map ~f suffix }
    end

    let string_of_field : bool list -> string = Coding.string_of_field

    let field_of_string = Coding.field_of_string

    let serialize' t ~pack =
      { Rendered.prefix = t.field_elements
      ; suffix = pack_bits ~max_size:254 ~pack t |> Array.of_list_rev
      }

    let serialize t ~string_of_field ~pack =
      let () =
        if Array.length t.field_elements > 0 then
          assert (String.length (string_of_field t.field_elements.(0)) = 32)
        else ()
      in
      serialize' t ~pack |> Rendered.map ~f:string_of_field
  end
end
