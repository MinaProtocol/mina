use js_sys::{Array, Uint8Array};
use serde::ser::{self, Error as _, Serialize};
use wasm_bindgen::prelude::*;

use super::{Error, Result};

pub struct ErrorSerializer;

impl ser::SerializeTupleVariant for ErrorSerializer {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_field<T: ?Sized + Serialize>(&mut self, _: &T) -> Result<()> {
        Err(Error::custom("Serializing variants is not implemented"))
    }

    fn end(self) -> Result {
        Err(Error::custom("Serializing variants is not implemented"))
    }
}

impl ser::SerializeStructVariant for ErrorSerializer {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_field<T: ?Sized + Serialize>(&mut self, _: &'static str, _: &T) -> Result<()> {
        Err(Error::custom("Serializing variants is not implemented"))
    }

    fn end(self) -> Result {
        Err(Error::custom("Serializing variants is not implemented"))
    }
}

pub struct ArraySerializer<'s> {
    serializer: &'s Serializer,
    res: Array,
    idx: u32,
}

impl<'s> ArraySerializer<'s> {
    pub fn new(serializer: &'s Serializer) -> Self {
        let res = Array::new();
        res.set(0, JsValue::from(0u32));
        Self {
            serializer,
            res,
            idx: 1,
        }
    }
}

impl ser::SerializeSeq for ArraySerializer<'_> {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_element<T: ?Sized + Serialize>(&mut self, value: &T) -> Result<()> {
        self.res.set(self.idx, value.serialize(self.serializer)?);
        self.idx += 1;
        Ok(())
    }

    fn end(self) -> Result {
        Ok(self.res.into())
    }
}

impl ser::SerializeTuple for ArraySerializer<'_> {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_element<T: ?Sized + Serialize>(&mut self, value: &T) -> Result<()> {
        ser::SerializeSeq::serialize_element(self, value)
    }

    fn end(self) -> Result {
        Ok(self.res.into())
    }
}

impl ser::SerializeTupleStruct for ArraySerializer<'_> {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_field<T: ?Sized + Serialize>(&mut self, value: &T) -> Result<()> {
        ser::SerializeTuple::serialize_element(self, value)
    }

    fn end(self) -> Result {
        Ok(self.res.into())
    }
}

impl ser::SerializeMap for ErrorSerializer {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_key<T: ?Sized + Serialize>(&mut self, _: &T) -> Result<()> {
        Err(Error::custom("Serializing maps is not implemented"))
    }

    fn serialize_value<T: ?Sized + Serialize>(&mut self, _: &T) -> Result<()> {
        Err(Error::custom("Serializing maps is not implemented"))
    }

    fn end(self) -> Result {
        Err(Error::custom("Serializing maps is not implemented"))
    }
}

impl ser::SerializeStruct for ArraySerializer<'_> {
    type Ok = JsValue;
    type Error = Error;

    fn serialize_field<T: ?Sized + Serialize>(&mut self, _: &'static str, value: &T) -> Result<()> {
        ser::SerializeSeq::serialize_element(self, value)
    }

    fn end(self) -> Result {
        Ok(self.res.into())
    }
}

#[derive(Default)]
pub struct Serializer(serde_wasm_bindgen::Serializer);

impl Serializer {
    pub fn new() -> Self {
        Self(serde_wasm_bindgen::Serializer::new())
    }
}

impl<'s> ser::Serializer for &'s Serializer {
    type Ok = JsValue;
    type Error = Error;

    type SerializeSeq = ArraySerializer<'s>;
    type SerializeTuple = ArraySerializer<'s>;
    type SerializeTupleStruct = ArraySerializer<'s>;
    type SerializeTupleVariant = ErrorSerializer;
    type SerializeMap = ErrorSerializer;
    type SerializeStruct = ArraySerializer<'s>;
    type SerializeStructVariant = ErrorSerializer;

    #[inline]
    fn is_human_readable(&self) -> bool {
        false
    }

    fn serialize_bool(self, v: bool) -> Result {
        if v {
            self.0.serialize_u32(1)
        } else {
            self.0.serialize_u32(0)
        }
    }

    fn serialize_i8(self, v: i8) -> Result {
        self.0.serialize_i8(v)
    }

    fn serialize_i16(self, v: i16) -> Result {
        self.0.serialize_i16(v)
    }

    fn serialize_i32(self, v: i32) -> Result {
        self.0.serialize_i32(v)
    }

    fn serialize_u8(self, v: u8) -> Result {
        self.0.serialize_u8(v)
    }

    fn serialize_u16(self, v: u16) -> Result {
        self.0.serialize_u16(v)
    }

    fn serialize_u32(self, v: u32) -> Result {
        self.0.serialize_u32(v)
    }

    fn serialize_f32(self, v: f32) -> Result {
        self.0.serialize_f32(v)
    }

    fn serialize_f64(self, v: f64) -> Result {
        self.0.serialize_f64(v)
    }

    fn serialize_str(self, _: &str) -> Result {
        /* The bindings call caml_string_of_jsstring; not clear what to do here without digging in
        further. */
        Err(Error::custom("Serializing strings is not implemented"))
    }

    fn serialize_i64(self, _: i64) -> Result {
        /* Custom type in OCaml */
        Err(Error::custom("Serializing i64 is not implemented"))
    }

    fn serialize_u64(self, _: u64) -> Result {
        /* Custom type in OCaml */
        Err(Error::custom("Serializing u64 is not implemented"))
    }

    fn serialize_i128(self, _: i128) -> Result {
        /* Custom type in OCaml */
        Err(Error::custom("Serializing i128 is not implemented"))
    }

    fn serialize_u128(self, _: u128) -> Result {
        /* Custom type in OCaml */
        Err(Error::custom("Serializing u128 is not implemented"))
    }

    fn serialize_char(self, v: char) -> Result {
        self.0.serialize_u32(v as u32)
    }

    fn serialize_bytes(self, v: &[u8]) -> Result {
        Ok(JsValue::from(Uint8Array::new(
            unsafe { Uint8Array::view(v) }.as_ref(),
        )))
    }

    fn serialize_none(self) -> Result {
        self.0.serialize_u32(0)
    }

    fn serialize_some<T: ?Sized + Serialize>(self, value: &T) -> Result {
        let res = Array::new();
        res.set(0, JsValue::from(0u32));
        res.set(1, value.serialize(self)?);
        Ok(res.into())
    }

    fn serialize_unit(self) -> Result {
        self.0.serialize_u32(0)
    }

    fn serialize_unit_struct(self, _: &'static str) -> Result {
        Err(Error::custom("Serializing unit structs is not implemented"))
    }

    fn serialize_unit_variant(self, _: &'static str, _: u32, _: &'static str) -> Result {
        Err(Error::custom(
            "Serializing unit variants is not implemented",
        ))
    }

    fn serialize_newtype_struct<T: ?Sized + Serialize>(self, _: &'static str, _: &T) -> Result {
        Err(Error::custom(
            "Serializing newtype structs is not implemented",
        ))
    }

    fn serialize_newtype_variant<T: ?Sized + Serialize>(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: &T,
    ) -> Result {
        Err(Error::custom(
            "Serializing newtype variants is not implemented",
        ))
    }

    // TODO: Figure out if there is a way to detect and serialise `Set` differently.
    fn serialize_seq(self, _: Option<usize>) -> Result<Self::SerializeSeq> {
        Ok(ArraySerializer::new(self))
    }

    fn serialize_tuple(self, _: usize) -> Result<Self::SerializeTuple> {
        Ok(ArraySerializer::new(self))
    }

    fn serialize_tuple_struct(
        self,
        _: &'static str,
        _: usize,
    ) -> Result<Self::SerializeTupleStruct> {
        Err(Error::custom(
            "Serializing tuple structs is not implemented",
        ))
    }

    fn serialize_tuple_variant(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: usize,
    ) -> Result<Self::SerializeTupleVariant> {
        Err(Error::custom(
            "Serializing tuple variants is not implemented",
        ))
    }

    fn serialize_map(self, _: Option<usize>) -> Result<Self::SerializeMap> {
        Err(Error::custom("Serializing maps is not implemented"))
    }

    fn serialize_struct(self, _: &'static str, _: usize) -> Result<Self::SerializeStruct> {
        Ok(ArraySerializer::new(self))
    }

    fn serialize_struct_variant(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: usize,
    ) -> Result<Self::SerializeStructVariant> {
        Err(Error::custom(
            "Serializing struct variants is not implemented",
        ))
    }
}
