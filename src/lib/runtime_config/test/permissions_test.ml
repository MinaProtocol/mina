open Core_kernel

module Permissions = Runtime_config.Json_layout.Accounts.Single.Permissions

let parse json =
  Permissions.of_yojson (Yojson.Safe.from_string json) |> Result.ok_or_failwith

let auth =
  Alcotest.testable
    (fun fmt t ->
      Format.pp_print_string fmt
        (Yojson.Safe.to_string (Permissions.Auth_required.to_yojson t)) )
    Poly.equal

(* The current layout gives [set_verification_key] as a bare authorization. *)
let reads_and_writes_bare_auth () =
  let permissions = parse {json|{ "set_verification_key": "proof" }|json} in
  Alcotest.check auth "parsed" Proof permissions.set_verification_key ;
  match Permissions.to_yojson permissions with
  | `Assoc fields ->
      Alcotest.(check string)
        "written" {|"proof"|}
        (Yojson.Safe.to_string
           (List.Assoc.find_exn fields ~equal:String.equal
              "set_verification_key" ) )
  | _ ->
      Alcotest.fail "permissions are not written as an object"

(* Configs from earlier releases give it with a transaction version, which is
   ignored. *)
let reads_legacy_record () =
  let permissions =
    parse
      {json|{ "set_verification_key": { "auth": "signature", "txn_version": "3" } }|json}
  in
  Alcotest.check auth "parsed" Signature permissions.set_verification_key

let () =
  Alcotest.run "Runtime config permissions"
    [ ( "set_verification_key"
      , [ Alcotest.test_case "reads and writes a bare authorization" `Quick
            reads_and_writes_bare_auth
        ; Alcotest.test_case "reads the legacy record" `Quick
            reads_legacy_record
        ] )
    ]
