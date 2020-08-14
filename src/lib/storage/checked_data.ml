open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = {checksum: Core_kernel.Md5.Stable.V1.t; data: 'a}
  end
end]

let md5 (tc : 'a Binable.m) data =
  Md5.digest_string (Binable.to_string tc data)

let wrap tc data : string t =
  let data = Binable.to_string tc data in
  {checksum= Md5.digest_string data; data}

let valid {checksum; data} = Md5.(equal (digest_string data) checksum)
