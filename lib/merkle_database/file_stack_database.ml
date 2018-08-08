open Core

module Make (Element : sig
  val size : int
end) =
struct
  type peano_number = Zero | Succ of peano_number

  type t =
    {fd: Unix.File_descr.t; filename: string; mutable num_elem: peano_number}

  let create ~filename =
    let open UnixLabels in
    let mode = [O_RDWR; O_CREAT; O_APPEND] in
    let fd = Unix.openfile ~mode filename in
    {fd; filename; num_elem= Zero}

  let clear t =
    t.num_elem <- Zero ;
    ignore @@ Unix.ftruncate t.fd ~len:(Int64.of_int 0)

  let destroy t =
    let {fd; filename} = t in
    Unix.close fd

  let push t (message: Bigstring.t) =
    t.num_elem <- Succ t.num_elem ;
    assert (Element.size = Unix.write t.fd (Bigstring.to_bytes message))

  let pop t =
    match t.num_elem with
    | Zero -> None
    | Succ num_elem ->
        t.num_elem <- num_elem ;
        let buf = Bytes.create Element.size in
        let file_offset =
          Unix.lseek t.fd (Int64.of_int @@ (-1 * Element.size)) SEEK_END
        in
        let num_chars_read = Unix.read t.fd ~buf ~pos:0 ~len:Element.size in
        assert (Element.size = num_chars_read) ;
        Unix.ftruncate t.fd ~len:file_offset ;
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
      let uuid = Uuid.create () in
      let dir_name = "/tmp/merkle_database_test-" ^ Uuid.to_string uuid in
      let stack_db_file = Filename.concat dir_name "sdb" in
      (fun () ->
        File_system.with_temp_dirs [dir_name] ~f:(fun () ->
            let t = Test.create stack_db_file in
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
        | Pop ->
            let elem = Test.pop t in
            match stack with
            | head :: tail ->
                assert (Some head = elem) ;
                tail
            | [] ->
                assert (None = elem) ;
                []
      in
      with_test (fun t ->
          Quickcheck.test ~sexp_of:[%sexp_of : command List.t]
            (Quickcheck.Generator.list command_gen) ~f:(fun commands ->
              let expected_stack =
                List.fold ~init:[] commands ~f:(test_command t)
              in
              assert_same_stack expected_stack t ;
              Test.clear t ) )
  end )
