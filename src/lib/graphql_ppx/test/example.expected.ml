module Address =
  struct
    type t = {
      dummy: unit }
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
          siblings: unit r query } -> unit r query 
        let ((dummy)[@field :unit]) =
          field "dummy" ~typ:() ~resolve:() ~args:[]
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
        let ((id)[@field :int]) = field "id" ~typ:() ~resolve:() ~args:[]
        let ((name)[@field :string]) =
          field "name" ~typ:() ~resolve:() ~args:[]
        let ((address)[@field :Address.t]) =
          field "address" ~typ:() ~resolve:() ~args:[]
      end
  end
