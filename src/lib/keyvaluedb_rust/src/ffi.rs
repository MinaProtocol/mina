use std::{borrow::Borrow, cell::RefCell, rc::Rc};

use ocaml_interop::{
    bigarray::Array1, ocaml_export, DynBox, FromOCaml, OCaml, OCamlInt, OCamlList, OCamlRef,
    OCamlRuntime, ToOCaml,
};

use crate::{batch::Batch, Database};

pub struct DatabaseFFI(pub Rc<RefCell<Option<Database>>>);
pub struct BatchFFI(pub Rc<RefCell<Batch>>);

type OCamlBigstring = Array1<u8>;

fn with_db<F, R>(
    rt: &mut &mut OCamlRuntime,
    db: OCamlRef<DynBox<DatabaseFFI>>,
    fun: F,
) -> std::io::Result<R>
where
    F: FnOnce(&mut Database) -> std::io::Result<R>,
{
    let db = rt.get(db);
    let db: &DatabaseFFI = db.borrow();
    let mut db = db.0.borrow_mut();
    let db = db
        .as_mut()
        .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::NotFound, "Database was closed"))?;

    fun(db)
}

fn with_batch<F, R>(rt: &mut &mut OCamlRuntime, db: OCamlRef<DynBox<BatchFFI>>, fun: F) -> R
where
    F: FnOnce(&mut Batch) -> R,
{
    let db = rt.get(db);
    let db: &BatchFFI = db.borrow();
    let mut db = db.0.borrow_mut();

    fun(&mut db)
}

fn get<V, T: FromOCaml<V>>(rt: &mut &mut OCamlRuntime, value: OCamlRef<V>) -> T {
    let value = rt.get(value);
    value.to_rust::<T>()
}

fn get_bigstring(rt: &mut &mut OCamlRuntime, value: OCamlRef<Array1<u8>>) -> Box<[u8]> {
    let value = rt.get(value);
    Box::<[u8]>::from(value.as_slice())
}

fn get_list_of<V, T, F>(
    rt: &mut &mut OCamlRuntime,
    values: OCamlRef<OCamlList<V>>,
    fun: F,
) -> Vec<T>
where
    F: Fn(OCaml<V>) -> T,
{
    let mut values_ref = rt.get(values);

    let mut values = Vec::with_capacity(2048);
    while let Some((head, tail)) = values_ref.uncons() {
        let key: T = fun(head);

        values.push(key);
        values_ref = tail;
    }

    values
}

ocaml_export! {
    fn rust_ondisk_database_create(
        rt,
        dir_name: OCamlRef<String>
    ) -> OCaml<Result<DynBox<DatabaseFFI>, String>> {
        let dir_name: String = get(rt, dir_name);

        Database::create(dir_name)
            .map(|db| DatabaseFFI(Rc::new(RefCell::new(Some(db)))))
            .map(|db| OCaml::box_value(rt, db).root())
            .map_err(|e| format!("{:?}", e))
            .to_ocaml(rt)
    }

    fn rust_ondisk_database_get_uuid(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>
    ) -> OCaml<Result<String, String>> {
        with_db(rt, db, |db| {
            Ok(db.get_uuid().clone())
        })
        .map_err(|e| format!("{:?}", e))
        .to_ocaml(rt)
    }

    fn rust_ondisk_database_close(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>
    ) -> OCaml<Result<(), String>> {
        {
            let db = rt.get(db);
            let db: &DatabaseFFI = db.borrow();
            let mut db = db.0.borrow_mut();
            let db = db.take().unwrap();
            db.close();

            std::mem::drop(db);
        }

        Ok::<_, String>(()).to_ocaml(rt)
    }

    fn rust_ondisk_database_get(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        key: OCamlRef<OCamlBigstring>,
    ) -> OCaml<Result<Option<OCamlBigstring>, String>> {
        // We avoid to copy the key here
        let db = {
            let db = rt.get(db);
            let db: &DatabaseFFI = db.borrow();
            Rc::clone(&db.0)
        };

        let mut db = db.borrow_mut();

        db.as_mut()
          .ok_or_else(|| "Database was closed".to_string())
          .and_then(|db| {
                let key: OCaml<OCamlBigstring> = rt.get(key);
                let key: &[u8] = key.as_slice();

                db.get(key).map_err(|e| format!("{:?}", e))
          })
          .to_ocaml(rt)
    }

    fn rust_ondisk_database_set(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        key: OCamlRef<OCamlBigstring>,
        value: OCamlRef<OCamlBigstring>,
    ) -> OCaml<Result<(), String>> {
        let key: Box<[u8]> = get_bigstring(rt, key);
        let value: Box<[u8]> = get_bigstring(rt, value);

        with_db(rt, db, |db| {
            db.set(key, value)
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_get_batch(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        keys: OCamlRef<OCamlList<OCamlBigstring>>,
    ) -> OCaml<Result<OCamlList<Option<OCamlBigstring>>, String>> {
        let keys: Vec<Box<[u8]>> = get_list_of(rt, keys, |v| v.as_slice().into());

        with_db(rt, db, |db| {
            db.get_batch(keys)
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_set_batch(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        remove_keys: OCamlRef<OCamlList<OCamlBigstring>>,
        key_data_pairs: OCamlRef<OCamlList<(OCamlBigstring, OCamlBigstring)>>,
    ) -> OCaml<Result<(), String>> {
        let remove_keys: Vec<Box<[u8]>> = get_list_of(rt, remove_keys, |v| {
            v.as_slice().into()
        });

        let key_data_pairs: Vec<(Box<[u8]>, Box<[u8]>)> = get_list_of(rt, key_data_pairs, |v| {
            let (key, value) = v.to_tuple();

            let key = key.as_slice().into();
            let value = value.as_slice().into();

            (key, value)
        });

        with_db(rt, db, |db| {
            db.set_batch(key_data_pairs, remove_keys)
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_make_checkpoint(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        directory: OCamlRef<String>
    ) -> OCaml<Result<(), String>> {
        let directory: String = get(rt, directory);

        with_db(rt, db, |db| {
            db.make_checkpoint(directory.as_str())
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_create_checkpoint(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        directory: OCamlRef<String>
    ) -> OCaml<Result<DynBox<DatabaseFFI>, String>> {
        let directory: String = get(rt, directory);

        with_db(rt, db, |db| {
            db.create_checkpoint(directory.as_str())
        })
         .map(|checkpoint| DatabaseFFI(Rc::new(RefCell::new(Some(checkpoint)))))
         .map(|checkpoint| OCaml::box_value(rt, checkpoint).root())
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_remove(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        key: OCamlRef<OCamlBigstring>,
    ) -> OCaml<Result<(), String>> {
        let key: Box<[u8]> = get_bigstring(rt, key);

        with_db(rt, db, |db| {
            db.remove(key)
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_to_alist(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
    ) -> OCaml<Result<OCamlList<(OCamlBigstring, OCamlBigstring)>, String>> {
        with_db(rt, db, |db| {
            db.to_alist()
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }

    fn rust_ondisk_database_batch_create(
        rt,
        _index: OCamlRef<OCamlInt>,
    ) -> OCaml<DynBox<BatchFFI>> {
        let batch: Batch = Batch::new();
        let batch: BatchFFI = BatchFFI(Rc::new(RefCell::new(batch)));
        OCaml::box_value(rt, batch)
    }

    fn rust_ondisk_database_batch_set(
        rt,
        batch: OCamlRef<DynBox<BatchFFI>>,
        key: OCamlRef<OCamlBigstring>,
        value: OCamlRef<OCamlBigstring>,
    ) {
        let key: Box<[u8]> = get_bigstring(rt, key);
        let value: Box<[u8]> = get_bigstring(rt, value);

        with_batch(rt, batch, |batch| {
            batch.set(key, value)
        });

        OCaml::unit()
    }

    fn rust_ondisk_database_batch_remove(
        rt,
        batch: OCamlRef<DynBox<BatchFFI>>,
        key: OCamlRef<OCamlBigstring>,
    ) {
        let key: Box<[u8]> = get_bigstring(rt, key);

        with_batch(rt, batch, |batch| {
            batch.remove(key)
        });

        OCaml::unit()
    }

    fn rust_ondisk_database_batch_run(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
        batch: OCamlRef<DynBox<BatchFFI>>,
    ) -> OCaml<Result<(), String>> {
        let result = {
            let db = rt.get(db);
            let db: &DatabaseFFI = db.borrow();
            let mut db = db.0.borrow_mut();
            let db = db.as_mut().unwrap();

            let batch = rt.get(batch);
            let batch: &BatchFFI = batch.borrow();
            let mut batch = batch.0.borrow_mut();

            db.run_batch(&mut batch)
        };

        result.map_err(|e| format!("{:?}", e))
              .to_ocaml(rt)
    }

    fn rust_ondisk_database_gc(
        rt,
        db: OCamlRef<DynBox<DatabaseFFI>>,
    ) -> OCaml<Result<(), String>> {
        with_db(rt, db, |db| {
            db.gc()
        })
         .map_err(|e| format!("{:?}", e))
         .to_ocaml(rt)
    }
}
