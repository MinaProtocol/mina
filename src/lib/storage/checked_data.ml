open Core_kernel

type 'a t = {checksum: Md5.t; data: 'a} [@@deriving bin_io]

let md5 (tc : 'a Binable.m) data =
  Md5.digest_string (Binable.to_string tc data)

let wrap tc data : string t =
  let data = Binable.to_string tc data in
  {checksum= Md5.digest_string data; data}

let valid {checksum; data} = Md5.(equal (digest_string data) checksum)
