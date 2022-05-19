module Address =
  struct
    type t = {
      dummy: unit }
    module Fields = struct let dummy = () end
    module Gql =
      struct
        type 'dummy r = {
          res_dummy: 'dummy }
        type 'a modifier = 'a option
        type out = t modifier
        type _ query =
          | Empty: unit r query 
          | Dummy: {
          siblings: unit r query } -> unit r query 
      end
  end
module Contact =
  struct
    type t =
      {
      id: int ;
      name: string ;
      address: Address.t [@subquery "Address.Gql"]}
    module Fields = struct let id = ()
                           let name = ()
                           let address = () end
    module Mutations = struct let set_name = () end
    module Gql =
      struct
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
          | Address:
          {
          siblings: ('id, 'name, unit) r query ;
          subquery: 'a Address.Gql.query } -> ('id, 'name,
          'a Address.Gql.modifier) r query 
      end
  end
