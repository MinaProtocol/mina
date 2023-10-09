Mina_caqti
==========

This library is designed to assist in querying relational databases
using the Caqti library. It is used extensively for querying the
archive database in the `Processor` and `Load_data` modules in
`Archive_lib`.

Constructing SQL queries
------------------------

Instead of writing out SQL queries as text, the
functions here can construct those queries from table information.

For example, the `Token` module in the archive processor contains:
```ocaml
  let table_name = "tokens"

  let find_by_id (module Conn : CONNECTION) id =
    Conn.find
      (Caqti_request.find Caqti_type.int typ
         (Mina_caqti.select_cols_from_id ~table_name ~cols:Fields.names) )
      id
```
The list `Fields.names` is generated from the `deriving fields` annotation on
the type `Token.t`. The call to `select_cols_fromid` constructs the query
```
SELECT value,owner_public_key_id,owner_token_id FROM tokens WHERE id = ?
```

There are other SQL-building functions in the library, like
`select_cols`, `insert_into_cols`, and `select_insert_into_cols`, which
are documented in the source code.

Custom array types
------------------

Another notable feature of the library are the custom array types,
which are used to provide a `Caqti.Type.t` for OCaml array types not
already built into Caqti.  For example, `array_int_typ` is used to
give a type for the OCaml type `int array`. Such Caqti types can be
used for the input or result type of queries, or to provide type
annotations on columns in queries. In some cases, PostgreSQL may not
be able to decode data without such annotations. There's an example of
using an annotation in
`Archive_lib.Processor.Zkapp_field_array.add_if_doesn't_exist`.

Encoding values as NULLs
------------------------

In the descriptions of the functions that follow, please note that the
values returned are in the `Deferred` monad, because they are the
result of database queries. For the `add...` functions, the result
actually has a `Deferred.Result.t` type, because queries can fail. For
the `get...` functions, a failure raises an exception.

There are some zkApps-related functions that are useful for storing
`Set_or_keep.t` and `Or_ignore.t` values. The function
`add_if_zkapp_set` runs a query if the data is `Set`, returning its
result (if it succeeds), and if the data is `Keep`, returns `None`.
Similarly, `add_if_zkapp_check` runs a query if the data is `Check`,
returning its result (if it succeeds), and if the data is `Ignore`,
returns `None`.  The functions `get_zkapp_set_or_keep` and
`get_zkapp_or_ignore` symmetrically, by converting a queried value to
a value construct with `Set` or `Check`, if not NULL, and converting a
NULL to `Keep` or `Ignore`. The use of NULL to encode these
zkApp-related values is mentioned as the `NULL convention` in the part
of the database schema in `zkapp_tables.sql`.

The functions `add_if_some` and `get_opt_item` are similar to these
zkApps-related functions, except that the constructors involved are
`Some` and `None` for option types. Therefore, `add_if_some` runs its
query argument if the data has `Some` as its constructor, returning
the result, and otherwise returns `None`. The function `get_opt_item`
returns a `Some`-constructed value, if the item is not NULL in the
database, and `None` otherwise.
