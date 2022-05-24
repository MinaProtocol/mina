module Address =
  struct
    type t = {
      dummy: int }
    type 'a final_option_modifier = 'a
    module Gql =
      struct
        open (Graphql_utils.Wrapper.Make2)(Graphql_async.Schema)
        type 'dummy r = {
          res_dummy: 'dummy }
        type 'a modifier = 'a option
        type out = t modifier
        type _ query =
          | Empty: unit r query 
          | Dummy: {
          siblings: unit r query } -> int r query 
        let ((dummy)[@field :int]) =
          field "dummy" ~typ:(non_null int)
            ~resolve:(fun _ -> fun t -> t.dummy) ~args:[]
        let typ () =
          obj "Address" ~fields:(fun _ -> let open Fields in [dummy])
      end
  end
module Contact =
  struct
    type t = {
      id: int ;
      name: string ;
      address: Address.t }
    type 'a final_option_modifier = 'a
    module Gql =
      struct
        open (Graphql_utils.Wrapper.Make2)(Graphql_async.Schema)
        type ('id, 'name, 'address) r =
          {
          res_id: 'id ;
          res_name: 'name ;
          res_address: 'address }
        type 'a modifier = 'a option
        type out = t modifier
        type _ query =
          | Empty: (unit, unit, unit) r query 
          | Id: {
          siblings: (unit, 'name, 'address) r query } -> (int, 'name,
          'address) r query 
          | Name: {
          siblings: ('id, unit, 'address) r query } -> ('id, string,
          'address) r query 
          | Address: {
          siblings: ('id, 'name, unit) r query } -> ('id, 'name, Address.t) r
          query 
        let ((id)[@field :int]) =
          field "id" ~typ:(non_null int) ~resolve:(fun _ -> fun t -> t.id)
            ~args:[]
        let ((name)[@field :string]) =
          field "name" ~typ:(non_null string)
            ~resolve:(fun _ -> fun t -> t.name) ~args:[]
        let ((address)[@field :Address.t]) =
          field "address" ~typ:(Address.Gql.typ ())
            ~resolve:(fun _ -> fun t -> Some (t.address)) ~args:[]
        let typ () =
          obj "Contact"
            ~fields:(fun _ -> let open Fields in [id; name; address])
      end
  end
