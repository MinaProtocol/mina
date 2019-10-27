**snarky-universe** is a snarky standard library that provides functions for dealing
with various useful objects (field elements, hashes, Merkle trees, signatures, integers).

## API documentation

Full API docs are available here.

### "Constant" module pattern

Most modules in **snarky-universe** have a submodule called "Constant". For example,
there is a module `Field` with the submodule `Field.Constant`.

`Field` provides operations on "in SNARK" variable field elements, whereas
`Field.Constant` provides operations on regular old field elements.

The difference is the following. The only things you can fundamentally do with "in snark" field
elements is add and multiply them. With "Constant" field elements, you can look at their bits,
turn them into a string, print them out to the console, etc.
