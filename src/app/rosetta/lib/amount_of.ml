open Core_kernel
open Models

module Token_id = struct
  let encode token_id =
    `Assoc [("token_id", `String (Unsigned.UInt64.to_string token_id))]

  module T (M : Monad_fail.S) = struct
    let decode metadata =
      match metadata with
      | Some (`Assoc [("token_id", `String token_id)])
        when try
               let _ = Unsigned.UInt64.of_string token_id in
               true
             with Failure _ -> false ->
          M.return (Some (Unsigned.UInt64.of_string token_id))
      | Some bad ->
          M.fail
            (Errors.create
               ~context:
                 (sprintf
                    "When metadata is provided for account identifiers, \
                     acceptable format is exactly { \"token_id\": \
                     <string-encoded-uint64> }. You provided %s"
                    (Yojson.Safe.pretty_to_string bad))
               (`Json_parse None))
      | None ->
          M.return None
  end
end

let coda total =
  { Amount.value= Unsigned.UInt64.to_string total
  ; currency= {Currency.symbol= "CODA"; decimals= 9l; metadata= None}
  ; metadata= None }

let token token_id total =
  (* TODO: Should we depend on coda_base so we can refer to Token_id.default instead? *)
  if token_id = Unsigned.UInt64.of_int 1 then coda total
  else
    { Amount.value= Unsigned.UInt64.to_string total
    ; currency=
        { Currency.symbol= "CODA+"
        ; decimals= 9l
        ; metadata= Some (Token_id.encode token_id) }
    ; metadata= None }
