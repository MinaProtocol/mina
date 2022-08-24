include Account_id.Digest

let deriver obj =
  (* this doesn't use js_type:Field because it is converted to JSON differently than a normal Field *)
  Fields_derivers_zkapps.iso_string obj ~name:"TokenId"
    ~js_type:(Custom "TokenId") ~doc:"String representing a token ID" ~to_string
    ~of_string:(Fields_derivers_zkapps.except ~f:of_string `Token_id)
