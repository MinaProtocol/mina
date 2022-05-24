module%derive_graphql Address = struct
  type t = {
    dummy : int;
  }

  type 'a final_option_modifier = 'a

  module Fields = struct
    let dummy [@field: int] = {
      typ = non_null int;
      args = [];
      resolve = (fun _ t -> t.dummy)
    }
  end
end

module%derive_graphql Contact = struct
  type t = {
    id: int;
    name: string;
    address: Address.t;
  }

  type 'a final_option_modifier = 'a

  module Fields = struct
    let id [@field: int] = {
      typ = non_null int;
      args = [];
      resolve = (fun _ t -> t.id)
    }
    let name [@field: string] = {
      typ = non_null string;
      args = [];
      resolve = (fun _ t -> t.name)
    }
    let address [@field: Address.t] = {
      typ = Address.Gql.typ ();
      args = [];
      resolve = (fun _ t -> Some t.address)
    }
  end
end
