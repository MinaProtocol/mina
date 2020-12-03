open Core

(* this is only a partial (minimum required) implementation of the terraform json spec *)
let cons (type a) (key : string) (body : a) (to_yojson : a -> Yojson.Safe.t) =
  `Assoc [(key, to_yojson body)]

type provider = string * string

let provider_to_yojson (provider, alias) = `String (provider ^ "." ^ alias)

type depends_on = provider list [@@deriving to_yojson]

module Backend = struct
  module S3 = struct
    type t =
      {key: string; encrypt: bool; region: string; bucket: string; acl: string}
    [@@deriving to_yojson]
  end

  type t = S3 of S3.t

  let to_yojson = function S3 x -> cons "s3" x S3.to_yojson
end

module Block = struct
  module Terraform = struct
    type t = {required_version: string; backend: Backend.t}
    [@@deriving to_yojson]
  end

  (* should probably leave these untyped, but this covers basic keys for both google and aws *)
  module Provider = struct
    type t =
      { provider: string
      ; region: string
      ; alias: string option
      ; project: string option
      ; zone: string option }
    [@@deriving to_yojson]

    let to_yojson {provider; region; alias; project; zone} =
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
      ; providers: (string * provider) list
      ; source: string
      ; args: (string * Yojson.Safe.t) list }

    let to_yojson {local_name; providers; source; args} =
      cons local_name () (fun () ->
          let const_fields =
            [ ( "providers"
              , `Assoc
                  (List.map providers ~f:(fun (k, v) ->
                       (k, provider_to_yojson v) )) )
            ; ("source", `String source) ]
          in
          `Assoc (const_fields @ args) )
  end

  module Data = struct
    type t =
      { data_source: string
      ; local_name: string
      ; args: (string * Yojson.Safe.t) list }

    let to_yojson {data_source; local_name; args} =
      cons data_source () (fun () -> cons local_name () (fun () -> `Assoc args))
  end

  module Resource = struct
    type t =
      {type_: string; local_name: string; args: (string * Yojson.Safe.t) list}

    let to_yojson {type_; local_name; args} =
      cons type_ () (fun () -> cons local_name () (fun () -> `Assoc args))
  end

  type t =
    | Terraform of Terraform.t
    | Provider of Provider.t
    | Module of Module.t
    | Data of Data.t
    | Resource of Resource.t

  let to_yojson = function
    | Terraform x ->
        cons "terraform" x Terraform.to_yojson
    | Provider x ->
        cons "provider" x Provider.to_yojson
    | Module x ->
        cons "module" x Module.to_yojson
    | Data x ->
        cons "data" x Data.to_yojson
    | Resource x ->
        cons "resource" x Resource.to_yojson
end

type t = Block.t list [@@deriving to_yojson]

let to_string = Fn.compose Yojson.Safe.pretty_to_string to_yojson
