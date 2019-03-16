open Core
open Async
open Stationary
open Util

type t =
  { date: Date.t
  ; title: string
  ; subtitle: string option
  ; author: string
  ; author_website: string option
  ; content: Html.t
  ; basename: string }

let load path =
  print_endline path ;
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
      let author_website =
        List.Assoc.find ~equal:String.equal kvs "author_website"
      in
      let subtitle = List.Assoc.find ~equal:String.equal kvs "subtitle" in
      { date
      ; title
      ; subtitle
      ; author
      ; author_website
      ; content= html
      ; basename= Filename.chop_extension (Filename.basename path) }
