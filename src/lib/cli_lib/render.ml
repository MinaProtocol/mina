open Core_kernel

module type Printable_intf = sig
  type t [@@deriving to_yojson]

  val to_text : t -> string
end

let print (type t) (module Print : Printable_intf with type t = t) is_json =
  function
  | Ok t ->
      if is_json then
        printf "%s\n" (Print.to_yojson t |> Yojson.Safe.pretty_to_string)
      else printf "%s\n" (Print.to_text t)
  | Error e -> eprintf "%s" (Error.to_string_hum e)

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
  type t = Coda_base.Payment_proof.t [@@deriving yojson]

  let to_text merkle_list =
    sprintf
      !"Merkle List of transactions:\n%s"
      (to_yojson merkle_list |> Yojson.Safe.pretty_to_string)
end

module Public_key_with_balances = struct
  type t = (int * string) list [@@deriving yojson]

  type format = {accounts: t} [@@deriving yojson, fields]

  let to_yojson t = format_to_yojson {accounts= t}

  let to_text pk_with_accounts =
    List.map pk_with_accounts ~f:(fun (pk, account) ->
        sprintf !"%d, %s" pk account )
    |> String_list_formatter.to_text
end
