open Core

module Base58_check = Base58_check.Make (struct
  let version_byte = Base58_check.Version_bytes.graphql
end)

module User_command = struct
  let serialize user_command =
    let bigstring =
      Bin_prot.Utils.bin_dump Coda_base.User_command.Stable.V1.bin_t.writer
        user_command
    in
    Base58_check.encode (Bigstring.to_string bigstring)

  let deserialize serialized_payment =
    let open Or_error.Let_syntax in
    let%map serialized_transaction = Base58_check.decode serialized_payment in
    Coda_base.User_command.Stable.V1.bin_t.reader.read
      (Bigstring.of_string serialized_transaction)
      ~pos_ref:(ref 0)
end
