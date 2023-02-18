open Core_kernel

let uint32_be =
  Lmdb.Conv.make
    ~flags:Lmdb.Conv.Flags.(integer_key + integer_dup + dup_fixed)
    ~serialise:(fun alloc x ->
      let a = alloc 4 in
      Bigstring.set_uint32_be_exn a ~pos:0 x ;
      a )
    ~deserialise:(Bigstring.get_uint32_be ~pos:0)
    ()

let uint8 =
  Lmdb.Conv.make
    ~flags:Lmdb.Conv.Flags.(integer_key + integer_dup + dup_fixed)
    ~serialise:(fun alloc x ->
      let a = alloc 1 in
      Bigstring.set_uint8_exn a ~pos:0 x ;
      a )
    ~deserialise:(Bigstring.get_uint8 ~pos:0)
    ()

let blake2 =
  Lmdb.Conv.(
    make
      ~serialise:(fun alloc x ->
        let str = Blake2.to_raw_string x in
        serialise string alloc str )
      ~deserialise:(fun s -> deserialise string s |> Blake2.of_raw_string)
      ())

let bin_prot_conv (t : 'a Bin_prot.Type_class.t) =
  Lmdb.Conv.(
    make
      ~serialise:(fun alloc x ->
        let sz = t.writer.size x in
        let res = alloc sz in
        let _pos = t.writer.write ~pos:0 res in
        res )
      ~deserialise:
        (let pos_ref = ref 0 in
         t.reader.read ~pos_ref )
      ())
