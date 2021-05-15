open Core

(* this is only a partial (minimum required) implementation of the terraform json spec *)
let cons (type a) (key : string) (body : a) (yojson_of : a -> Yojson.Safe.t) =
  `Assoc [(key, yojson_of body)]

module Backend = struct
  module S3 = struct
    type t =
      {key: string; encrypt: bool; region: string; bucket: string; acl: string}
    [@@deriving yojson_of]
  end

  type t = S3 of S3.t

  let yojson_of_t = function S3 x -> cons "s3" x S3.yojson_of
end

module Block = struct
  module Terraform = struct
    type t = {required_version: string; backend: Backend.t}
    [@@deriving yojson_of]
  end

  (* should probably leave these untyped, but this covers basic keys for both google and aws *)
  module Provider = struct
    type t =
      { provider: string
      ; region: string
      ; alias: string option
      ; project: string option
      ; zone: string option }
    [@@deriving yojson_of]

    let yojson_of_t {provider; region; alias; project; zone} =
      cons provider () (fun () ->
          let open Option.Let_syntax in
          let field k v = (k, `String v) in
          let fields =
            [ Some (field "region" region)
            ; alias >>| field "alias"
            ; project >>| field "project"
            ; zone >>| field "zone" ]
          in
          `Assoc (List.filter_map fields ~f:Fn.id) )
  end

  module Module = struct
    type t =
      { local_name: string
      ; providers: (string * string) list
      ; source: string
      ; args: (string * Yojson.Safe.t) list }

    let yojson_of_t {local_name; providers; source; args} =
      cons local_name () (fun () ->
          let const_fields =
            [ ( "providers"
              , `Assoc (List.map providers ~f:(fun (k, v) -> (k, `String v)))
              )
            ; ("source", `String source) ]
          in
          `Assoc (const_fields @ args) )
  end

  module Data = struct
    type t =
      { data_source: string
      ; local_name: string
      ; args: (string * Yojson.Safe.t) list }

    let yojson_of_t {data_source; local_name; args} =
      cons data_source () (fun () -> cons local_name () (fun () -> `Assoc args))
  end

  module Resource = struct
    type t =
      {type_: string; local_name: string; args: (string * Yojson.Safe.t) list}

    let yojson_of_t {type_; local_name; args} =
      cons type_ () (fun () -> cons local_name () (fun () -> `Assoc args))
  end

  type t =
    | Terraform of Terraform.t
    | Provider of Provider.t
    | Module of Module.t
    | Data of Data.t
    | Resource of Resource.t

  let yojson_of_t = function
    | Terraform x ->
        cons "terraform" x Terraform.yojson_of
    | Provider x ->
        cons "provider" x Provider.yojson_of
    | Module x ->
        cons "module" x Module.yojson_of
    | Data x ->
        cons "data" x Data.yojson_of
    | Resource x ->
        cons "resource" x Resource.yojson_of
end

type t = Block.t list [@@deriving yojson_of]

let to_string = Fn.compose Yojson.Safe.pretty_to_string yojson_of
