## Summary
[summary]: #summary

This RFC introduces a mechanism for datatype generic programming (see [motivation](#motivation) for a definition) that is easier to maintain than ppx macros but still powerful enough for innumerable use cases in our codebase (graphql, bridges between languages, random oracle inputs, etc.). This document additionally decribes its specific application to Snapp parties transactions. While this RFC will describe all ways this approach simplifies our Snapp parties implementation, the scope of work on this project will leave some derivers for future work.

## Motivation
[motivation]: #motivation

Datatype generic programming sometimes referred to as reflection refers to a form of abstraction for creating reusable logic that acts on a wide variety of datatypes. Typically this is used to fold over data structures to "automatically" implement toJson, toString, hash, equals, etc.

Specifically with respect to Snapps transactions: We have complex nested structures to define the new parties transaction and at the moment, we redeclare JSON, GraphQL, JS/OCaml bridges, specifications, and TypeScript definitions in SnarkyJS completely separately. This is error-prone, hard to maintain, and has already introduced bugs in our Snapps implementation even before we've shipped v1. Using datatype generic programming, we can define all of these only once, atomically on each primitive of the datatype, never forget to update when definitions change (the compiler will yell at us), and rely on the datatype generic machinery to perform the structural fold for us.

In OCaml, we'd look for some form of datatype generic programming that allows us to fold over algebraic datatypes and records. Typically, in Mina's codebase we have used ppx deriving macros. `[@@deriving yojson]` derives a JSON serializer and deserializer and `[@@deriving sexp]` derives an S-expression parser and printer.

While PPX macros are very powerful, writing custom PPX macros is extremely difficult in OCaml, unfortunately, and very hard to maintain.

Luckily, folks at Jane Street have implemented a mechanism to mechanically, generically, define folds on arbitrary data types in OCaml using the `[@@deriving fields]` macros that is written with "common OCaml" and anyone familiary with Jane Street libraries in OCaml, ie. most contributors to the Mina OCaml core, can maintain. 

```ocaml
(* to_string from the ppx_fields_conv docs *)
type t = {
  dir : [ `Buy | `Sell ];
  quantity : int;
  price : float;
  mutable cancelled : bool;
  symbol : string;
} [@@deriving fields]

let to_string t =
  let conv to_s = fun acc f ->
    (sprintf "%s: %s" (Field.name f) (to_s (Field.get f t))) :: acc
  in
  let fs =
    Fields.fold ~init:[]
      ~dir:(conv (function `Buy -> "Buy" | `Sell -> "Sell"))
      ~quantity:(conv Int.to_string)
      ~price:(conv Float.to_string)
      ~cancelled:(conv Bool.to_string)
  in
  String.concat fs ~sep:", "
```

This is a step in the right direction but we can make this more succinct with terser combinators:

```ocaml
type t = {
  dir : [ `Buy | `Sell ];
  quantity : int;
  price : float;
  mutable cancelled : bool;
  symbol : string;
} [@@deriving fields]

let to_string t =
  let open To_string.Combinators in
  String.concat ~sep:", " @@
      Fields.fold ~init:[]
        ~dir
        ~quantity:int
        ~price:float
        ~cancelled:bool
```

Further we can build combinators for horizontally composing derivers such that:

```ocaml
type t = {
  dir : [ `Buy | `Sell ];
  quantity : int;
  price : float;
  mutable cancelled : bool;
  symbol : string;
} [@@deriving fields]

let derive t =
  let module Combinators = Derive.Make2(To_string)(To_equal) in
  let open Combinators in
  let dir = both Dir.to_string Dir.to_yojson in
  Fields.fold ~init ~dir ~quantity:int ~price:float ~cancelled:bool |> finish

let to_string = derive t |> fst
let equal = derive t |> snd
(* etc. *)
```

Coupled with combinators these custom folds are almost powerful enough.

However, sometimes we need to add metadata to our data types in order to faithfully implement some fold. For example, we may want to provide a custom field name in a JSON serializer or documentation for a GraphQL schema.

Rather than pollute our data types we can settle for one extra relatively simple companion macro that I propose we call `[@@deriving ann]` we can pull out all the custom annotations on the datatype and finally have enough machinery for us to cleanly implement JSON, GraphQL, specifications, random oracle inputs, typescript definitions, and more.

## Detailed design
[detailed-design]: #detailed-design

### General Framework

TODO


```ocaml
(* TODO *)

module type Deriver = sig
  module Source = struct type t end
  module Init = struct type t ; val init : t end
  module Finish = struct type t end

  val t : Source.t -> Finish.t
end

module Make2 (D1 : Deriver) (D2 : Deriver) : Deriver = struct
  type t = D1.t * D2.t

  module Init = struct
    type t = D1.Init.t * D2.Init.t
    let init = D1.Init.init * D2.Init.init
  end
  module Finish = struct
    type t = D1.Finish.t * D2.Finish.t
  end

end

```

#### Deriving Annotations

We need to implement a `[@@deriving ann]` macro that takes a structure that looks something like:

```ocaml
type t =
  { foo : int (** foo must be greater than zero *)
  ; reserved : string [@key "_reserved"]
  }
[@@deriving ann]
```

and produces something like (sketch):

```ocaml
let t_ann : Ann.t Field.Map.t
```

where there is helper code:

```ocaml
(* helper util code that we only need once *)
module Ann = struct
  type t =
    { ocaml_doc : string
    ; key : string
    (* any other annotations we want to capture *)
    }

  module Field = struct
    module T = struct
      type 'a t = | E : ('a, 'b) Field.t -> 'a t
      (* ... with a sort function based on the Field name *)
    end

    module Map = Core_kernel.Map.Make(T)
  end

  (* wraps your field in the existential wrapper for you and then does a map
     lookup *)
  val get : ('a, 'b) Field.t -> Ann.t Field.Map.t -> Ann.t option
end
```

Now we can build combinators on our field folds assuming a `t_ann` value is in scope.

#### Combinators

TODO

#### Recipes

TODO


```ocaml
module Reflection = struct
  let regex = lazy (Re2.create_exn {regex|\_(\w)|regex})

  let underToCamel s =
    Re2.replace_exn (Lazy.force regex) s ~f:(fun m ->
        let s = Re2.Match.get_exn ~sub:(`Index 1) m in
        String.capitalize s)

  (** When Fields.folding, create graphql fields via reflection *)
  let reflect f ~typ acc x =
    let new_name = underToCamel (Field.name x) in
    Schema.(
      field new_name ~typ ~args:Arg.[] ~resolve:(fun _ v -> f (Field.get x v))
      :: acc)

  module Shorthand = struct
    open Schema

    (* Note: Eta expansion is needed here to combat OCaml's weak polymorphism nonsense *)

    let id ~typ a x = reflect Fn.id ~typ a x

    let nn_int a x = id ~typ:(non_null int) a x

    let int a x = id ~typ:int a x

    let nn_bool a x = id ~typ:(non_null bool) a x

    let bool a x = id ~typ:bool a x

    let nn_string a x = id ~typ:(non_null string) a x

    let nn_time a x =
      reflect
        (fun t -> Block_time.to_time t |> Time.to_string)
        ~typ:(non_null string) a x

    let nn_catchup_status a x =
      reflect
        (fun o ->
          Option.map o
            ~f:
              (List.map ~f:(function
                | ( Transition_frontier.Full_catchup_tree.Node.State.Enum
                    .Finished
                  , _ ) ->
                    "finished"
                | Failed, _ ->
                    "failed"
                | To_download, _ ->
                    "to_download"
                | To_initial_validate, _ ->
                    "to_initial_validate"
                | To_verify, _ ->
                    "to_verify"
                | Wait_for_parent, _ ->
                    "wait_for_parent"
                | To_build_breadcrumb, _ ->
                    "to_build_breadcrumb"
                | Root, _ ->
                    "root")))
        ~typ:(list (non_null string))
        a x

    let string a x = id ~typ:string a x

    module F = struct
      let int f a x = reflect f ~typ:Schema.int a x

      let nn_int f a x = reflect f ~typ:Schema.(non_null int) a x

      let string f a x = reflect f ~typ:Schema.string a x

      let nn_string f a x = reflect f ~typ:Schema.(non_null string) a x
    end
  end
end
```

### Applications for Snapps Parties (minimal)

A minimal application of this mechanism applied to snapps transactions would be to 

TODO

### Applications for Snapps Parties (phase2)

TODO

### Other Applications

Other applications to explore are specification deriving using ocaml doccomments on data structures and random oracle input `to_input` derivation rather than relying on HLists.

## Drawbacks
[drawbacks]: #drawbacks

To fully adopt this vision, we'll need to rewrite a lot of different pieces within Mina. Luckily, this can be done piecemeal and whenever we decide to allocate effort toward individual sections.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

We could stick with PPX macros but they are too hard to write. Other sorts of code genreators don't fit into our workfflow.

We could also not take any sort of datatype generic approach of dealing with this issue and instead write the same thing manually or stick with what we've done so far -- however, as mentioned above we are already running into bugs and are concerned about maintainability of the current implementation.

In an effort to avoid digging ourselves further in a tech debt hole, this RFC proposes we adopt this generic programming approach immediately.

## Prior art
[prior-art]: #prior-art

TODO

In Haskell, generic programming

In Swift, generic programming


Discuss prior art, both the good and the bad, in relation to this proposal.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

To resolve during implementation:
* To what extent do we re-write the datastructures in the bridge using this mechanism vs keep it scoped to GraphQL for now?


