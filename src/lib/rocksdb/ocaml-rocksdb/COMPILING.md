You need some opam packages
```
opam install ctypes.0.4.0 ctypes-foreign
```


You'll also need to install rocksdb. There's a script that can do this for you, see [install_rocksdb.sh].
[install_rocksdb.sh]: install_rocksdb.sh

Afterwards run `make` in the root dir of this repository.
The package can be installed with `make install`.
