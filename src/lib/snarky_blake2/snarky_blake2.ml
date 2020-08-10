open Core_kernel

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  val block_size_in_bits : int

  val digest_length_in_bits : int

  val blake2s :
       ?personalization:string
    -> Boolean.var array
    -> (Boolean.var array, _) Checked.t
end

module Make (Impl : Snarky_backendless.Snark_intf.S) :
  S with module Impl := Impl = struct
  open Impl
  open Let_syntax
  module UInt32 = Uint32.Make (Impl)

  let r1 = 16

  let r2 = 12

  let r3 = 8

  let r4 = 7

  let ( := ) (v, i) t =
    let%map x = t in
    v.(i) <- x

  let mixing_g v a b c d x y =
    let ( := ) i t = (v, i) := t in
    let open UInt32 in
    let xorrot t1 t2 k = xor t1 t2 >>| Fn.flip UInt32.rotr k in
    let%bind () = a := sum [v.(a); v.(b); x] in
    let%bind () = d := xorrot v.(d) v.(a) r1 in
    let%bind () = c := sum [v.(c); v.(d)] in
    let%bind () = b := xorrot v.(b) v.(c) r2 in
    let%bind () = a := sum [v.(a); v.(b); y] in
    let%bind () = d := xorrot v.(d) v.(a) r3 in
    let%bind () = c := sum [v.(c); v.(d)] in
    let%bind () = b := xorrot v.(b) v.(c) r4 in
    return ()

  let iv =
    Array.map
      ~f:(Fn.compose UInt32.constant UInt32.Unchecked.of_int)
      [| 0x6A09E667
       ; 0xBB67AE85
       ; 0x3C6EF372
       ; 0xA54FF53A
       ; 0x510E527F
       ; 0x9B05688C
       ; 0x1F83D9AB
       ; 0x5BE0CD19 |]

  let splitu64 u =
    let open Unsigned.UInt64 in
    let open Infix in
    let uint32 = Fn.compose UInt32.Unchecked.of_int to_int in
    let low = uint32 (u land of_int 0xffffffff) in
    let high = uint32 (u lsr 32) in
    (low, high)

  let for_ n ~f =
    let rec go i =
      if i = n then return ()
      else
        let%bind () = f i in
        go (i + 1)
    in
    go 0

  let sigma =
    [| [|0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15|]
     ; [|14; 10; 4; 8; 9; 15; 13; 6; 1; 12; 0; 2; 11; 7; 5; 3|]
     ; [|11; 8; 12; 0; 5; 2; 15; 13; 10; 14; 3; 6; 7; 1; 9; 4|]
     ; [|7; 9; 3; 1; 13; 12; 11; 14; 2; 6; 5; 10; 4; 0; 15; 8|]
     ; [|9; 0; 5; 7; 2; 4; 10; 15; 14; 1; 11; 12; 6; 8; 3; 13|]
     ; [|2; 12; 6; 10; 0; 11; 8; 3; 4; 13; 7; 5; 15; 14; 1; 9|]
     ; [|12; 5; 1; 15; 14; 13; 4; 10; 0; 7; 6; 3; 9; 2; 8; 11|]
     ; [|13; 11; 7; 14; 12; 1; 3; 9; 5; 0; 15; 4; 8; 6; 2; 10|]
     ; [|6; 15; 14; 9; 11; 3; 0; 8; 12; 2; 13; 7; 1; 4; 10; 5|]
     ; [|10; 2; 8; 4; 7; 6; 1; 5; 15; 11; 9; 14; 3; 12; 13; 0|] |]

  let compression h (m : UInt32.t array) t f =
    assert (Array.length h = 8) ;
    assert (Array.length m = 16) ;
    let v = Array.append h iv in
    let open UInt32 in
    let tlo, thi = splitu64 t in
    let%bind () = (v, 12) := xor v.(12) (constant tlo) in
    let%bind () = (v, 13) := xor v.(13) (constant thi) in
    let%bind () =
      (* We only perform this step while processing the last block,
         at which point f is always equal to Unsigned.UInt32.max_int *)
      if f then (v, 14) := xor v.(14) (constant UInt32.Unchecked.max_int)
      else return ()
    in
    let%bind () =
      for_ 10 ~f:(fun i ->
          let s = sigma.(i) in
          let mix a b c d i1 i2 = mixing_g v a b c d m.(s.(i1)) m.(s.(i2)) in
          let%bind () = mix 0 4 8 12 0 1 in
          let%bind () = mix 1 5 9 13 2 3 in
          let%bind () = mix 2 6 10 14 4 5 in
          let%bind () = mix 3 7 11 15 6 7 in
          let%bind () = mix 0 5 10 15 8 9 in
          let%bind () = mix 1 6 11 12 10 11 in
          let%bind () = mix 2 7 8 13 12 13 in
          let%bind () = mix 3 4 9 14 14 15 in
          return () )
    in
    let%bind () =
      for_ 8 ~f:(fun i ->
          let%bind () = (h, i) := xor h.(i) v.(i) in
          (h, i) := xor h.(i) v.(Int.(i + 8)) )
    in
    return ()

  let block_size_in_bits = 512

  let digest_length_in_bits = 256

  let pad_input bs =
    let n = Array.length bs in
    if n mod block_size_in_bits = 0 then bs
    else
      Array.append bs
        (Array.create
           ~len:(block_size_in_bits - (n mod block_size_in_bits))
           Boolean.false_)

  let concat_int32s (ts : UInt32.t array) =
    let n = Array.length ts in
    Array.init (n * UInt32.length_in_bits) ~f:(fun i ->
        ts.(i / UInt32.length_in_bits).(i mod UInt32.length_in_bits) )

  let default_personalization = String.init 8 ~f:(fun _ -> '\000')

  let blake2s ?(personalization = default_personalization) input =
    assert (String.length personalization = 8) ;
    let p o =
      let c j = Char.to_int personalization.[o + j] lsl (8 * j) in
      c 0 + c 1 + c 2 + c 3
    in
    let h =
      (* Here we xor the initial values with the parameters of the
         hash function that we're using:
         depth = 1
         fanout = 1
         digest_length = 32
         personalization = personalization *)
      Array.map
        ~f:(Fn.compose UInt32.constant UInt32.Unchecked.of_int)
        [| 0x6A09E667 lxor 0x01010000 (* depth = 1, fanout = 1 *) lxor 32
           (* digest_length = 32 *)
         ; 0xBB67AE85
         ; 0x3C6EF372
         ; 0xA54FF53A
         ; 0x510E527F
         ; 0x9B05688C
         ; 0x1F83D9AB lxor p 0
         ; 0x5BE0CD19 lxor p 4 |]
    in
    let padded = pad_input input in
    let blocks : UInt32.t array array =
      let n = Array.length padded in
      if n = 0 then
        [| Array.create
             ~len:(block_size_in_bits / UInt32.length_in_bits)
             UInt32.zero |]
      else
        Array.init (n / block_size_in_bits) ~f:(fun i ->
            Array.init (block_size_in_bits / UInt32.length_in_bits)
              ~f:(fun j ->
                Array.init UInt32.length_in_bits ~f:(fun k ->
                    padded.((block_size_in_bits * i)
                            + (UInt32.length_in_bits * j)
                            + k) ) ) )
    in
    let%bind () =
      for_
        (Array.length blocks - 1)
        ~f:(fun i ->
          compression h blocks.(i)
            Unsigned.UInt64.(Infix.((of_int i + one) * of_int 64))
            false )
    in
    let input_length_in_bytes = (Array.length input + 7) / 8 in
    let%bind () =
      compression h
        blocks.(Array.length blocks - 1)
        (Unsigned.UInt64.of_int input_length_in_bytes)
        true
    in
    return (concat_int32s h)
end

let%test_module "blake2-equality test" =
  ( module struct
    (* Delete once the snarky pr lands *)
    module Impl =
      Snarky_backendless.Snark0.Make (Snarky_backendless.Backends.Bn128.Default)
    include Make (Impl)

    let checked_to_unchecked typ1 typ2 checked input =
      let open Impl in
      let (), checked_result =
        run_and_check
          (let%bind input = exists typ1 ~compute:(As_prover.return input) in
           let%map result = checked input in
           As_prover.read typ2 result)
          ()
        |> Or_error.ok_exn
      in
      checked_result

    let test_equal (type a) ?(sexp_of_t = sexp_of_opaque) ?(equal = ( = )) typ1
        typ2 checked unchecked input =
      let checked_result = checked_to_unchecked typ1 typ2 checked input in
      let sexp_of_a = sexp_of_t in
      let compare_a x y = if equal x y then 0 else 1 in
      [%test_eq: a] checked_result (unchecked input)

    let blake2_unchecked s =
      Blake2.string_to_bits
        Blake2.(digest_string (Blake2.bits_to_string s) |> to_raw_string)

    let to_bitstring bits =
      String.init (Array.length bits) ~f:(fun i ->
          if bits.(i) then '1' else '0' )

    let%test_unit "constraint count" =
      assert (
        Impl.constraint_count
          (let open Impl in
          let%bind bits =
            exists
              (Typ.array ~length:512 Boolean.typ_unchecked)
              ~compute:(As_prover.return (Array.create ~len:512 true))
          in
          blake2s bits)
        <= 21278 )

    let%test_unit "blake2 equality" =
      let input =
        let open Quickcheck.Let_syntax in
        let%bind n = Int.gen_incl 0 (1024 / 8) in
        let%map x = String.gen_with_length n Char.quickcheck_generator in
        (n, Blake2.string_to_bits x)
      in
      let output_typ =
        Impl.Typ.array ~length:digest_length_in_bits Impl.Boolean.typ
      in
      Quickcheck.test ~trials:20 input ~f:(fun (n, input) ->
          let input_typ = Impl.Typ.array ~length:(8 * n) Impl.Boolean.typ in
          test_equal
            ~sexp_of_t:(Fn.compose [%sexp_of: string] to_bitstring)
            input_typ output_typ
            (blake2s ?personalization:None)
            blake2_unchecked input )
  end )
