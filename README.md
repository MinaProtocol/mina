# Saffron - A solution for mutable state management for Web3

## How to build

1. Clone the repository
```
git clone git@github.com:o1-labs/saffron.git
```
2. Go inside the saffron repository
```
cd saffron
```
3. Create an opam switch & import
```
opam switch create .
eval $(opam env)
```
4. Import the switch
```
opam switch import opam.export
```
5. Install dune
```
opam install dune
```
If dune is already installed but outdated, upgrade it:
```
opam upgrade dune
```
6. Build
```
dune build
```

## Resources

### Introduction

- [Introducing \[Project Untitled\]: Solving Web3’s State Management Problem](https://www.o1labs.org/blog/introducing-project-untitled)
- [Why Should Developers Have to Compromise on Web3 State Management?](https://www.o1labs.org/blog/project-untitled-technical-vision)
- [The Technical Foundations of [Project Untitled]](https://www.o1labs.org/blog/future-of-decentralized-trustless-apps)

## License
[Apache 2.0](LICENSE)
