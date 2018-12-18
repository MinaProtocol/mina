open Core
open Async
open Stationary
open Util

type t =
  { date: Date.t
  ; title: string
  ; author: string
  ; content: Html.t
  ; basename: string }

let load path =
  let%map markdown = Reader.file_contents path and html = Markdown.load path in
  match extract_kv_str markdown with
  | None ->
      failwithf "Markdown must have metadata block with date and title (%s)"
        path ()
  | Some kv_str ->
      let kvs =
        List.map (String.split_lines kv_str) ~f:(fun line ->
            match split_kv line with
            | Some (k, v) -> (String.strip k, String.strip v)
            | None ->
                failwithf
                  "Markdown_post.load: There must be exactly one `key: value` \
                   pair per line: %s"
                  line () )
      in
      let date =
        Date.of_string (List.Assoc.find_exn ~equal:String.equal kvs "date")
      in
      let title = List.Assoc.find_exn ~equal:String.equal kvs "title" in
      let author = List.Assoc.find_exn ~equal:String.equal kvs "author" in
      { date
      ; title
      ; author
      ; content= html
      ; basename= Filename.chop_extension (Filename.basename path) }
