module Copy_database = struct
  let run_drop_db (module Conn : Caqti_async.CONNECTION) ~copy_db = 
    Conn.exec
      (Caqti_request.exec
         Caqti_type.unit
         (Printf.sprintf 
         {sql| DROP database %s
         |sql} copy_db )
      ) ()
 
  let run (module Conn : Caqti_async.CONNECTION) ~original_db ~copy_db =
    Conn.exec
    (Caqti_request.exec
       Caqti_type.unit
       (Printf.sprintf
          {sql| CREATE DATABASE %s with TEMPLATE %s
                 |sql}
                 copy_db original_db 
                 )  ) ()
    

end

module Block = struct

  let run_state_hash (module Conn : Caqti_async.CONNECTION) =
    Conn.collect_list
    (Caqti_request.collect
       Caqti_type.unit Caqti_type.string
       {sql| SELECT state_hash from blocks
       |sql} )
    ()
    

  let run (module Conn : Caqti_async.CONNECTION) ~state_hash =
    Conn.find
    (Caqti_request.find
       Caqti_type.string Caqti_type.int
       {sql| SELECT id from blocks where state_hash = ?
       |sql} )
       state_hash

  let run_unset_parent (module Conn : Caqti_async.CONNECTION) id =
    Conn.exec
    (Caqti_request.exec
       Caqti_type.int
       {sql| UPDATE blocks SET parent_hash = NULL where id = ?
       |sql} )
    id

  let run_delete (module Conn : Caqti_async.CONNECTION) ~state_hash =
    Conn.exec
    (Caqti_request.exec
       Caqti_type.string
       {sql| DELETE CASCADE blocks where state_hash = ?
       |sql} )
    state_hash
end

