1. Intro
  - Why Functional Programming?
    - mutability
    - encapsulation
    - functional programming in Java is tedious (but possible)
  - Goal: Introduce what we will build at the very end (after async)
    - and show demo possible (or a snippet of code)

2. Basics
  - Utop (how to run)
  - End an expression with `;;`
  - Integers (and “all values have a type”)
  - Strings (and concatenation)
  - Lists (they’re linked lists)
  - Tuples (they’re not lists)
  - Let-bindings
    - Shadowing
  (exercise on using let-bindings)

3. Functions
    - function types (show `int_of_string`)
    - function application
    - functions are values (`let f = int_of_string ;;`)
    - currying and two arg functions (`(``+``)` like 5)
      - partial application
      - redefine it on a tuple (but we usually use currying): this is different!
    - Anonymous functions (`fun` keyword)
    - Defining functions
    - An example higher-order function (not map/filter/fold — nonrecursive)
      - Maybe something with parsing
  (examples and exercises)

4. ADTs and patternmatching (no recursive functions)
  - “enums” in Java
  - “enums” in OCaml (are sum types)
    - Int or String
    - This is what you can do that you can’t do in Java
    - Pattern-matching
  - “Algebraic of datatypes” (but don’t describe these now)
  - Recursive Datatypes
    - Lists (of ints)
    - Binary Tree (of ints)
  (examples and exercises:
    Should showcase: a problem that requires using creating new ADTs,
        using pattern matching on them
  )

5. Recursive functions
  - `let rec`
  - `length` (simple) (on list of ints)
    - Worth stepping through `length [1,2,3]`
  - string-concatenation on a tree (basically a fold, but don’t say that)
  - recursive function mental model
    - Think from the bottom up (start from the end)
      - Base case
      - Recursive case
  (examples and exercises:
    Should showcase: the same problems that we’ll do again in higher-order
    function section (example: write a function that removes the even numbers
    from a list, later we’ll ask them again with filter, (do it for a map and a
    fold also))
  )

6. Parametric Polymorphism (don’t use the words parametric polymorphism)
  - Datatypes
    - Lists (of ‘a)
    - Trees (of ‘a)
    - Option types
      - no nulls, no billion dollar mistake
    - Result type “either”
  - Functions
    - `List.length`
    - Implement `List.length`
    - Call length function on list of ints and list of strings
      - Unification
      - Step by step inference
  (examples and exercises: Using option, like head of a list)

7. Higher-order-function combinators (spend a lot of time on this)
  - Just lists
    - iter
    - map
    - filter
    - fold
  - Some examples on trees
  - Problem solving with higher-order-functions instead of recursion
    - LOTS OF EXAMPLES!!
  - Inference
    - Implement `length` again but now don’t write the type
    - EXAMPLE:
      - one pass `('a list → int) int t`
      - two step-pass with a function that invokes `map`
        - `(``'``a list → (``'``a → b) →` `'``b list) (int list) (int → string)`
        - step through the substitutions, show how each variable gets propagated
  (examples and exercises: 
    Show `map` implementation
    Ask to define `filter` . 
    Implement one of the `fold`s, (show the other)

    Review problems from recursion section, redo w/ real higher-order functions
  )

8. Mutation
  - You can do mutation, we tend to avoid it
  - When you need to do it, you can…
  - Some tradeoffs, typically faster but less safe
  - Arrays (briefly)
  - Unit
    - `printf`
    - it will show up when there are side-effects
    - Use `;` to chain values together
  (examples and exercises:
    fibonacci: functional in ocaml
    fibonacci: imperative in java,
    fibonacci: imperative in ocaml
  )

9. Modules
  - Consuming libraries
  - Modules as namespaces
  - Signatures and structures
    - What is a structure in ocaml, it’s not a struct in C
  - (Don’t talk about functors here)
  (examples and exercises:
    - Take a module with a larger signature, and show it constrained to `Sexpable`
    - write modules that conform to signatures `#show_module_type (module type of Int)`
  )

10. Async
  - Deferred
  - `Deferred.upon` and callbacks
    - but this is not a clean write to code, because it looks way different than sequential
  - `let and_then = Deferred.bind`
  - Do a lot of examples
    - Show a chain of deferreds binded
    - Explain how this is sequencing asynchronous things
    - Looks better than passing callbacks around
  - Transform examples to use the `>>=` operator
  - `let%bind` now it really looks like sequential (easier jump from `>>=`)
  (examples and exercises:
    Do big example (weather?)
  )

