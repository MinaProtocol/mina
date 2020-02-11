type account_data =
  { pk: Signature_lib.Public_key.Compressed.t
  ; sk: Signature_lib.Private_key.t option
  ; balance: Currency.Balance.t
  ; delegate: Signature_lib.Public_key.Compressed.t option }
[@@deriving yojson]

type t = account_data list [@@deriving yojson]

module Fake_accounts : sig
  val generate : int -> t
end
