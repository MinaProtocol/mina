open Graphql

type role = User | Admin

type user = {
  id   : int;
  name : string;
  role : role;
}

let users = ref [
  { id = 1; name = "Alice"; role = Admin };
  { id = 2; name = "Bob"; role = User };
]

let role_values = Schema.([
  enum_value "user" ~value:User;
  enum_value "admin" ~value:Admin;
])

let role = Schema.(enum "role" ~values:role_values)
let input_role = Schema.Arg.(enum "role" ~values:role_values)

let user = Schema.(obj "user"
  ~fields:(fun _ -> [
    field "id"
      ~typ:(non_null int)
      ~args:Arg.[]
      ~resolve:(fun { ctx = () } p -> p.id)
    ;
    field "name"
      ~typ:(non_null string)
      ~args:Arg.[]
      ~resolve:(fun _ p -> p.name)
    ;
    field "role"
      ~typ:(non_null role)
      ~args:Arg.[]
      ~resolve:(fun _ p -> p.role)
  ])
)

(* Not available in List before OCaml 4.07 *)
let list_to_seq n l =
  let rec aux n l () = match n, l with
    | _, [] | 0, _ -> Seq.Nil
    | _, x :: tail -> Seq.Cons (x, aux (n - 1) tail)
  in
  aux n l

let schema = Schema.(schema [
    field "users"
      ~typ:(non_null (list (non_null user)))
      ~args:Arg.[]
      ~resolve:(fun _ () -> !users)
    ]
    ~mutations:[
      field "add_user"
        ~typ:(non_null (list (non_null user)))
        ~args:Arg.[
          arg "name" ~typ:(non_null string);
          arg "role" ~typ:(non_null input_role)
        ]
        ~resolve:(fun _ () name role ->
          let id = Random.int 1000000 in
          users := List.append !users [{ id; name; role }];
          !users
        )
    ]
    ~subscriptions:[
      subscription_field "subscribe_to_user"
        ~typ:(non_null user)
        ~args:Arg.[
          arg' "error" ~typ:bool ~default:false;
          arg' "raise" ~typ:bool ~default:false;
          arg' "first" ~typ:int ~default:1;
        ]
        ~resolve:(fun _ return_error raise_in_stream first ->
          if return_error then
            Error "stream error"
          else if raise_in_stream then
            Ok (fun () -> Seq.Cons (raise Not_found, (fun () -> Seq.Nil)))
          else
            Ok (list_to_seq first !users))
    ]
)
