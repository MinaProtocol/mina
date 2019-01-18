
1. Intro
  - Why Functional Programming?
    - mutation leads to hard to code that is harder to understand — it’s hard think about every single state in our brains, functional programming helps us minimize the state-space
    - Look at the following code

```java
        public static int f(int n){
            if (n == 0) {
                return 0;
            }

            if (n == 1){
                return 1;
            }

            int first = 0;
            int second = 1;
            int nth = 1;

            for (int i = 2; i <= n; i++) {
                nth = first + second;
                first = second;
                second = nth;
            }
            return nth;
        }
```

  What is `nth`,`first`, `second` when `i=5`, moreover what is this function?


```java
        public static int f(int n){
          if (n == 0) { return n; }
          if (n == 1) { return n; }
          return f(n-1) + f(n-2);
        }
```

  What is this function?, what is the result when `n=5`?


  - how do you know nothing else in the code mutated something? Large code-bases suffer when there is excessive mutation as well...

  - functional programming in Java or Python is possible, but it’s not as straightforward (you have write a bunch of boilerplate). Here is fibonacci OCaml:

  ```ocaml
    let rec f = function
       | 0 -> 0
       | 1 -> 1
       | n -> f (n-2) + f (n-1)
  ```

- Goal: Introduce what we will build at the very end (after async)
  - and show demo possible (or a snippet of code)

TODO

