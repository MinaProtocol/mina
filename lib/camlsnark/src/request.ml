type _ t = ..

type _ t += Fail : 'a t

module Handler = struct
  type nonrec t = { handle : 'a. 'a t -> 'a }

  let fail = { handle = fun _ -> failwith "Request.Handler.fail" }

  let extend t1 t2 =
    { handle =
        fun r ->
          try t1.handle r
          with _ -> t2.handle r
    }
end
