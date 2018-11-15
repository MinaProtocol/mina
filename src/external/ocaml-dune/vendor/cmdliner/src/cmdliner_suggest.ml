(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   cmdliner v1.0.0
  ---------------------------------------------------------------------------*)

let levenshtein_distance s t =
  (* As found here http://rosettacode.org/wiki/Levenshtein_distance#OCaml *)
  let minimum a b c = min a (min b c) in
  let m = String.length s in
  let n = String.length t in
  (* for all i and j, d.(i).(j) will hold the Levenshtein distance between
     the first i characters of s and the first j characters of t *)
  let d = Array.make_matrix (m+1) (n+1) 0 in
  for i = 0 to m do d.(i).(0) <- i done;
  for j = 0 to n do d.(0).(j) <- j done;
  for j = 1 to n do
    for i = 1 to m do
      if s.[i-1] = t.[j-1] then
        d.(i).(j) <- d.(i-1).(j-1)  (* no operation required *)
      else
        d.(i).(j) <- minimum
            (d.(i-1).(j) + 1)   (* a deletion *)
            (d.(i).(j-1) + 1)   (* an insertion *)
            (d.(i-1).(j-1) + 1) (* a substitution *)
    done;
  done;
  d.(m).(n)

let value s candidates =
  let add (min, acc) name =
    let d = levenshtein_distance s name in
    if d = min then min, (name :: acc) else
    if d < min then d, [name] else
    min, acc
  in
  let dist, suggs = List.fold_left add (max_int, []) candidates in
  if dist < 3 (* suggest only if not too far *) then suggs else []

(*---------------------------------------------------------------------------
   Copyright (c) 2011 Daniel C. Bünzli

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
