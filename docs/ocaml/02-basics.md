Assuming everyone has a utop environment:

- 5
- 5+5
- 5 * 5

Integers, etc (normal)

- Every value has a type associated with it
- `"a"`
- `"a" ^ "b"`

String concatenation uses a `^`

Lists:

- [1 ; 2 ; 3]

Note the semicolons instead of commas. These are Linked-Lists

Tuples:

- (1, “a”)

You can group values together that are different types

Let-bindings:

In Java: (this is not a let binding, it’s a variable!)

```java
    int x = 3;
    return x + x
```

In python:

```python
    x = 3
    return x + x
```

In OCaml: (this is a let binding)

```ocaml
    let x = 3 in
    x + x
```

- `let x = 2+3 in x` `+` `x`

This is an expression!

- Step through evaluation semantics:
  - `let x = 2 + 3 in x + x` =>
  - `let x = 5 in x + x` =>
  - `5 + 5` =>
  - `10`

If we want a local variable we use `in`.

If you want to describe a top-level binding to reuse inside your utop session
you use `;;` and omit `in`:

- `let x = 4 ;;`
- `let x = 2 + 3 ;;`

Shadowing:

- `let x = 5 ;;`
- `x + x ;;` 10
- `let x = x + 2 in x + x`, what is this value?
- Notice: (Java)

```java
    int x = 0;
    for (int i = 0; i < 10; i++) {
       x = x + 1;
       System.out.println("x: " + x);
    }
    return x
```

This is DIFFERENT from (ocaml)

```ocaml
    let x = 0 in
    for i = 0 to 9 do
      let x = x + 1 in
      printf("x: " + x)
    done
    x
```

Exercise: Write an expression in utop that solves the problem
`(4^2 + 4^2) / 30^2` in a DRY manner (so don’t do `4*4` more than once, for
example).

