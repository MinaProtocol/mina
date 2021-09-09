type t = unit -> bool

let ith_bit s i = (Char.code s.[i / 8] lsr (i mod 8)) land 1 = 1

let digest_length_in_bits = 256

module State = struct
  type t = {digest: string; i: int; j: int}

  let update ~seed ({digest; i; j} as state) =
    if j = digest_length_in_bits then
      let digest =
        Digestif.SHA256.(
          digest_string (seed ^ string_of_int i) |> to_raw_string)
      in
      let b = ith_bit digest 0 in
      (b, {digest; i= i + 1; j= 1})
    else
      let b = ith_bit digest j in
      (b, {state with j= j + 1})

  let init ~seed =
    {digest= Digestif.SHA256.(digest_string seed |> to_raw_string); i= 0; j= 0}
end

let create ~seed : t =
  let s = ref (State.init ~seed) in
  fun () ->
    let b, s' = State.update ~seed !s in
    s := s' ;
    b
