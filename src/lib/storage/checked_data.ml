open Core_kernel

type 'a t = {checksum: Md5.t; data: 'a} [@@deriving bin_io]

let md5 (tc : 'a Bin_prot.Type_class.t) data =
  let buf = Bigstring.create (tc.writer.size data) in
  ignore (tc.writer.write buf ~pos:0 data) ;
  Md5.digest_string (Bigstring.to_string buf)

let wrap tc data : 'a t = {checksum= md5 tc data; data}

let valid c t = Md5.(md5 c t.data = t.checksum)
