open Ctypes

module BindStorage (T : functor (S : Sodium_storage.S) -> sig end) = struct
  module Bytes = T (Sodium_storage.Bytes)
  module Bigbytes = T (Sodium_storage.Bigbytes)
end

module Bind (F : Cstubs.FOREIGN) = struct
  include Sodium_bindings.C (F)
  module Sodium' = BindStorage (Make)
  module Random' = BindStorage (Random.Make)
  module Box' = BindStorage (Box.Make)
  module Sign' = BindStorage (Sign.Make)
  module Password_hash' = BindStorage (Password_hash.Make)
  module Secret_box' = BindStorage (Secret_box.Make)
  module Stream' = BindStorage (Stream.Make)
  module Hash' = BindStorage (Hash.Make)
  module Generichash' = BindStorage (Generichash.Make)

  module Auth = Gen_auth (struct
    let scope = "auth"

    let primitive = "hmacsha512256"
  end)

  module Auth' = BindStorage (Auth.Make)

  module One_time_auth = Gen_auth (struct
    let scope = "onetimeauth"

    let primitive = "poly1305"
  end)

  module One_time_auth' = BindStorage (One_time_auth.Make)
end

let () =
  let fmt = Format.formatter_of_out_channel (open_out "lib/sodium_stubs.c") in
  Format.fprintf fmt "#include <sodium.h>@." ;
  Cstubs.write_c fmt ~prefix:"caml_" (module Bind) ;

  let fmt =
    Format.formatter_of_out_channel (open_out "lib/sodium_generated.ml")
  in
  Cstubs.write_ml fmt ~prefix:"caml_" (module Bind)
