module Make (D : sig val digest_size : int end) = struct
  let to_hex hash =
    let res = Bytes.create (D.digest_size * 2) in

    let chr x = match x with
      | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 -> Char.chr (48 + x)
      | _ -> Char.chr (97 + (x - 10)) in

    for i = 0 to D.digest_size - 1
    do
      let v = Char.code (String.get hash i) in
      Bytes.unsafe_set res (i * 2) (chr (v lsr 4));
      Bytes.unsafe_set res (i * 2 + 1) (chr (v land 0x0F));
    done;

    Bytes.unsafe_to_string res

  let code x = match x with
    | '0' .. '9' -> Char.code x - 48
    | 'A' .. 'F' -> Char.code x - 55
    | 'a' .. 'z' -> Char.code x - 87
    | _ -> invalid_arg "of_hex"

  let decode chr1 chr2 = Char.chr ((code chr1 lsl 4) lor (code chr2))

  let of_hex hex =
    let offset = ref 0 in

    let rec go have_first idx =
      if !offset + idx >= String.length hex
      then '\x00'
      else match String.get hex (!offset + idx) with
        | ' ' | '\t' | '\r' | '\n' ->
          incr offset;
          go have_first idx
        | chr2 when have_first -> chr2
        | chr1 ->
          incr offset;
          let chr2 = go true idx in
          if chr2 <> '\x00'
          then decode chr1 chr2
          else invalid_arg "of_hex: odd number of hex characters" in
    String.init D.digest_size (go false)

  let consistent_of_hex str =
    let offset = ref 0 in
    let rec go have_first idx =
      if !offset + idx >= String.length str
      then invalid_arg "Not enough hex value"
      else match String.get str (!offset + idx) with
        | ' ' | '\t'| '\r' | '\n' ->
          incr offset;
          go have_first idx
        | chr2 when have_first -> chr2
        | chr1 ->
          incr offset;
          let chr2 = go true idx in
          decode chr1 chr2 in
    let res = String.init D.digest_size (go false) in
    let is_wsp = function ' ' | '\t'| '\r' | '\n' -> true | _ -> false in

    while (D.digest_size * 2) + !offset < String.length str
          && is_wsp (String.get str (!offset + (D.digest_size * 2)))
    do incr offset done;

    if !offset + (D.digest_size * 2) = String.length str
    then res else invalid_arg "Too much enough bytes"

  let pp ppf hash =
    for i = 0 to D.digest_size - 1
    do Format.fprintf ppf "%02x" (Char.code (String.get hash i)) done
end
