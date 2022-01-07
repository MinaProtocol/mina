let test_module (module M : Unsigned.S) =
  let on_int64 ~f ~f_64 x y =
    Format.eprintf "@.x_64, " ;
    flush stderr ;
    let x_64 = M.to_int64 x in
    Format.eprintf "y_64, " ;
    flush stderr ;
    let y_64 = M.to_int64 y in
    Format.eprintf "z, " ;
    flush stderr ;
    let z = f x y in
    Format.eprintf "z_64, " ;
    flush stderr ;
    let z_64 = f_64 x_64 y_64 in
    Format.eprintf "M.of_int64, " ;
    flush stderr ;
    let ret = (M.of_int64 z_64, z) in
    Format.eprintf "Done@." ; ret
  in
  let on_int ~f ~f_32 x y =
    let x_32 = M.to_int x in
    let y_32 = M.to_int y in
    let z = M.of_int (M.to_int (f x y)) in
    let z_32 = M.to_int (M.of_int (f_32 x_32 y_32)) in
    (M.of_int z_32, z)
  in
  let print (x, y) =
    Format.eprintf "Checking" ;
    flush stderr ;
    let x' = M.to_int64 x in
    let y' = M.to_int64 y in
    Format.eprintf ":" ;
    flush stderr ;
    let x' = Int64.to_string x' in
    Format.eprintf ":" ;
    flush stderr ;
    let y' = Int64.to_string y' in
    Format.eprintf ": " ;
    flush stderr ;
    Format.eprintf "%s = %s? " x' y' ;
    flush stderr ;
    Format.eprintf "%s = %s? " (M.to_string x) (M.to_string y) ;
    flush stderr ;
    Format.eprintf "%i@." (compare x' y') ;
    ignore (x, y)
  in
  let check (loc, x, y) =
    let x, y =
      on_int64 ~f:M.add ~f_64:Int64.add (M.of_int64 x) (M.of_int64 y)
    in
    print (x, y) ;
    if not (M.compare x y = 0) then failwith loc
  in
  List.iter check
    [ (__LOC__, -1L, -1L)
    ; (__LOC__, 0xFFL, 0xFFL)
    ; (__LOC__, 0xFFFFL, 0xFFFFL)
    ; (__LOC__, 0xFFFFFFL, 0xFFFFFFL)
    ; (__LOC__, 0xFFFFFFFFL, 0xFFFFFFFFL)
    ] ;
  let check (loc, x, y) =
    let x, y = on_int ~f:M.add ~f_32:( + ) (M.of_int64 x) (M.of_int64 y) in
    print (x, y) ;
    if not (x = y) then failwith loc
  in
  List.iter check
    [ (__LOC__, -1L, -1L)
    ; (__LOC__, 0xFFL, 0xFFL)
    ; (__LOC__, 0xFFFFL, 0xFFFFL)
    ; (__LOC__, 0xFFFFFFL, 0xFFFFFFL)
    ; (__LOC__, 0xFFFFFFFFL, 0xFFFFFFFFL)
    ]

let () =
  Format.eprintf "UInt8@." ;
  test_module (module Unsigned.UInt8) ;
  Format.eprintf "UInt16@." ;
  test_module (module Unsigned.UInt16) ;
  Format.eprintf "UInt32@." ;
  test_module (module Unsigned.UInt32) ;
  Format.eprintf "UInt64@." ;
  test_module (module Unsigned.UInt64)
