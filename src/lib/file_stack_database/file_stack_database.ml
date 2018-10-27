open Core

module Make (Element : sig
  val size : int
end) =
struct
  type t =
    {fd: Unix.File_descr.t; filename: string; mutable num_elem: Unsigned.UInt.t}

  let create ~filename =
    let open UnixLabels in
    let mode = [O_RDWR; O_CREAT; O_APPEND] in
    let fd = Unix.openfile ~mode filename in
    let char_position = Unix.lseek fd Int64.zero ~mode:SEEK_END in
    let num_elem =
      Unsigned.UInt.div
        (Unsigned.UInt.of_int64 char_position)
        (Unsigned.UInt.of_int Element.size)
    in
    {fd; filename; num_elem}

  let filename {filename; _} = filename

  let destroy t =
    let {fd; _} = t in
    Unix.close fd

  let push t (message : Bigstring.t) =
    t.num_elem <- Unsigned.UInt.succ t.num_elem ;
    assert (Element.size = Unix.write t.fd ~buf:(Bigstring.to_bytes message))

  let pop t =
    if Unsigned.UInt.compare t.num_elem Unsigned.UInt.zero = 0 then None
    else
      let buf = Bytes.create Element.size in
      let file_offset =
        Unix.lseek t.fd (Int64.of_int @@ (-1 * Element.size)) ~mode:SEEK_END
      in
      let num_chars_read = Unix.read t.fd ~buf ~pos:0 ~len:Element.size in
      assert (Element.size = num_chars_read) ;
      Unix.ftruncate t.fd ~len:file_offset ;
      t.num_elem <- Unsigned.UInt.pred t.num_elem ;
      Some (Bigstring.of_bytes buf)
end

let%test_module "file stack database" =
  ( module struct
    let size = 8

    module Test = Make (struct
      let size = size
    end)

    let string_gen =
      let open Quickcheck.Let_syntax in
      String.gen_with_length size Char.gen >>| Bigstring.of_string

    let with_test f =
      (fun () ->
        File_system.with_temp_dir
          (Filename.temp_dir_name ^/ "merkle_database_test")
          ~f:(fun dir_name ->
            let stack_db_file = Filename.concat dir_name "sdb" in
            let t = Test.create ~filename:stack_db_file in
            File_system.try_finally
              ~f:(fun () -> f t ; Async.Deferred.unit)
              ~finally:(fun () -> Test.destroy t ; Async.Deferred.unit) ) )
      |> Async.Thread_safe.block_on_async_exn

    let assert_same_stack expected_stack t =
      let values =
        List.init (List.length expected_stack) ~f:(fun _ ->
            Test.pop t |> Option.value_exn )
      in
      assert (expected_stack = List.rev values)

    type command = Push of Bigstring.t | Pop [@@deriving sexp]

    let%test_unit "behaves like a stack" =
      let command_gen =
        let open Quickcheck.Let_syntax in
        let%bind message = string_gen in
        Quickcheck.Generator.of_list [Push message; Pop]
      in
      let test_command t stack = function
        | Push message -> Test.push t message ; message :: stack
        | Pop -> (
            let elem = Test.pop t in
            match stack with
            | head :: tail ->
                assert (Some head = elem) ;
                tail
            | [] ->
                assert (None = elem) ;
                [] )
      in
      with_test (fun t ->
          Quickcheck.test ~sexp_of:[%sexp_of: command List.t]
            (Quickcheck.Generator.list command_gen) ~f:(fun commands ->
              let expected_stack =
                List.fold ~init:[] commands ~f:(test_command t)
              in
              assert_same_stack expected_stack t ) )

    let%test_unit "continue from previous state" =
      with_test (fun t ->
          Quickcheck.test ~sexp_of:[%sexp_of: Bigstring.t List.t]
            (Quickcheck.Generator.list string_gen) ~f:(fun strings ->
              let killed_t = t in
              List.iter strings ~f:(Test.push killed_t) ;
              Test.destroy killed_t ;
              let new_t = Test.create ~filename:(Test.filename t) in
              assert_same_stack (List.rev strings) new_t ) )
  end )
