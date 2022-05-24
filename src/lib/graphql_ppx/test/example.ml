module Address = [%derive_graphql
  type t = {
    dummy : int;
  }
  type 'a final_option_modifier = 'a

  module Fields = struct
    let dummy [@field: int] = {
      obj = "Address";
      typ = non_null int;
      args = [];
      resolve = (fun _ t -> t.dummy)
    }

    let typ () = obj "Address" ~fields:(fun _ -> [dummy])
  end
]

module Contact = [%derive_graphql
  type t = {
    id: int;
    name: string;
    address: Address.t;
  }
  type 'a final_option_modifier = 'a

  module Fields = struct

    let id [@field: int] = {
      obj = "Contact"; (* this should be factorized *)
      typ = non_null int;
      args = [];
      resolve = (fun _ t -> t.id)
    }
    let name [@field: string] = {
      obj = "Contact";
      typ = non_null string;
      args = [];
      resolve = (fun _ t -> t.name)
    }
    let address [@field: Address.t] = {
      obj = "Contact";
      typ = Address.Gql.typ ();
      args = [];
      resolve = (fun _ t -> Some t.address)
    }
  end
]
