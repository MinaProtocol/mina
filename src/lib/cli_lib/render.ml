open Core_kernel
open Coda_base

module type Printable_intf = sig
  type t [@@deriving to_yojson]

  val to_text : t -> string
end

let print (type t) (module Print : Printable_intf with type t = t) ~error_ctx
    is_json = function
  | Ok t ->
      if is_json then
        printf "%s\n" (Print.to_yojson t |> Yojson.Safe.pretty_to_string)
      else printf "%s\n" (Print.to_text t)
  | Error e ->
      eprintf "%s\n%s\n" error_ctx (Error.to_string_hum e)

module String_list_formatter = struct
  type t = string list [@@deriving yojson]

  let log10 i = i |> Float.of_int |> Float.log10 |> Float.to_int

  let to_text pks =
    let max_padding = Int.max 1 (List.length pks) |> log10 in
    List.mapi pks ~f:(fun i pk ->
        let i = i + 1 in
        let padding = String.init (max_padding - log10 i) ~f:(fun _ -> ' ') in
        sprintf "%s%i, %s" padding i pk )
    |> String.concat ~sep:"\n"
end

module Prove_receipt = struct
  type t = Receipt.Chain_hash.t * User_command.t list
  [@@deriving yojson]

  let to_text proof =
    sprintf
      !"Merkle List of transactions:\n%s"
      (to_yojson proof |> Yojson.Safe.pretty_to_string)
end

module Public_key_with_details = struct
  module Pretty_account = struct
    type t = string * int * int

    let to_yojson (public_key, balance, nonce) =
      `Assoc
        [ ( public_key
          , `Assoc [("balance", `Int balance); ("nonce", `Int nonce)] ) ]
  end

  type t = Pretty_account.t list [@@deriving to_yojson]

  type format = {accounts: t} [@@deriving to_yojson, fields]

  let to_yojson t = format_to_yojson {accounts= t}

  let to_text account =
    List.map account ~f:(fun (public_key, balance, nonce) ->
        sprintf !"%s, %d, %d" public_key balance nonce )
    |> String.concat ~sep:"\n"
end
