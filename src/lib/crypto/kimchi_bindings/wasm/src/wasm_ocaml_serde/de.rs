use js_sys::{Array, ArrayBuffer, Number, Uint8Array};
use serde::de::value::SeqDeserializer;
use serde::de::{self, Error as _, IntoDeserializer};
use wasm_bindgen::{JsCast, JsValue, UnwrapThrowExt};

use super::{Error, Result};

struct SeqAccess {
    iter: js_sys::IntoIter,
}

impl<'de> de::SeqAccess<'de> for SeqAccess {
    type Error = Error;

    fn next_element_seed<T: de::DeserializeSeed<'de>>(
        &mut self,
        seed: T,
    ) -> Result<Option<T::Value>> {
        Ok(match self.iter.next().transpose()? {
            Some(value) => Some(seed.deserialize(Deserializer::from(value))?),
            None => None,
        })
    }
}

struct ObjectAccess {
    data: Array,
    fields: std::slice::Iter<'static, &'static str>,
    idx: u32,
    next_value: Option<Deserializer>,
}

impl ObjectAccess {
    fn new(data: Array, fields: &'static [&'static str]) -> Self {
        // We start the index at 1, due to some js-of-ocaml expecting the first element to be 0
        // this is due to OCaml implementation details.
        Self {
            data,
            idx: 1,
            fields: fields.iter(),
            next_value: None,
        }
    }
}

fn str_deserializer(s: &str) -> de::value::StrDeserializer<Error> {
    de::IntoDeserializer::into_deserializer(s)
}

impl<'de> de::MapAccess<'de> for ObjectAccess {
    type Error = Error;

    fn next_key_seed<K: de::DeserializeSeed<'de>>(&mut self, seed: K) -> Result<Option<K::Value>> {
        debug_assert!(self.next_value.is_none());

        match self.fields.next() {
            None => Ok(None),
            Some(field) => {
                self.next_value = Some(Deserializer::from(self.data.get(self.idx)));
                self.idx += 1;
                Ok(Some(seed.deserialize(str_deserializer(field))?))
            }
        }
    }

    fn next_value_seed<V: de::DeserializeSeed<'de>>(&mut self, seed: V) -> Result<V::Value> {
        seed.deserialize(self.next_value.take().unwrap_throw())
    }
}

pub struct Deserializer(JsValue);

// Can't use `serde_wasm_bindgen::de::Deserializer`, its `value` field is private.
impl From<JsValue> for Deserializer {
    fn from(value: JsValue) -> Self {
        Self(value)
    }
}

// Ideally this would be implemented for `JsValue` instead, but we can't because
// of the orphan rule.
impl<'de> IntoDeserializer<'de, Error> for Deserializer {
    type Deserializer = Self;

    fn into_deserializer(self) -> Self::Deserializer {
        self
    }
}

impl Deserializer {
    fn as_bytes(&self) -> Option<Vec<u8>> {
        if let Some(v) = self.0.dyn_ref::<Uint8Array>() {
            Some(v.to_vec())
        } else {
            /* We can hit this case when the values have come from the non-serde conversions. */
            self.0
                .dyn_ref::<ArrayBuffer>()
                .map(|v| Uint8Array::new(v).to_vec())
        }
    }
}

impl<'de> de::Deserializer<'de> for Deserializer {
    type Error = Error;

    fn deserialize_any<V: de::Visitor<'de>>(self, _: V) -> Result<V::Value> {
        Err(Error::custom(
            "Inferring the serialized type is not implemented",
        ))
    }

    fn deserialize_unit<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_unit()
    }

    fn deserialize_unit_struct<V: de::Visitor<'de>>(
        self,
        _: &'static str,
        _: V,
    ) -> Result<V::Value> {
        Err(Error::custom(
            "Deserializing unit structs is not implemented",
        ))
    }

    fn deserialize_bool<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        let x = self.0.unchecked_into::<Number>().as_f64().unwrap() as u32;
        visitor.visit_bool(x != 0)
    }

    fn deserialize_f32<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_f32(self.0.unchecked_into::<Number>().as_f64().unwrap() as f32)
    }

    fn deserialize_f64<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_f64(self.0.unchecked_into::<Number>().as_f64().unwrap())
    }

    fn deserialize_identifier<V: de::Visitor<'de>>(self, _: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing strings is not implemented"))
    }

    fn deserialize_str<V: de::Visitor<'de>>(self, _: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing strings is not implemented"))
    }

    fn deserialize_string<V: de::Visitor<'de>>(self, _: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing strings is not implemented"))
    }

    fn deserialize_i8<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_i8(self.0.unchecked_into::<Number>().as_f64().unwrap() as i8)
    }

    fn deserialize_i16<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_i16(self.0.unchecked_into::<Number>().as_f64().unwrap() as i16)
    }

    fn deserialize_i32<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_i32(self.0.unchecked_into::<Number>().as_f64().unwrap() as i32)
    }

    fn deserialize_u8<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_u8(self.0.unchecked_into::<Number>().as_f64().unwrap() as u8)
    }

    fn deserialize_u16<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_u16(self.0.unchecked_into::<Number>().as_f64().unwrap() as u16)
    }

    fn deserialize_u32<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_u32(self.0.unchecked_into::<Number>().as_f64().unwrap() as u32)
    }

    fn deserialize_i64<V: de::Visitor<'de>>(self, _visitor: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing i64 is not implemented"))
    }

    fn deserialize_u64<V: de::Visitor<'de>>(self, _visitor: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing u64 is not implemented"))
    }

    fn deserialize_i128<V: de::Visitor<'de>>(self, _visitor: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing i128 is not implemented"))
    }

    fn deserialize_u128<V: de::Visitor<'de>>(self, _visitor: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing u128 is not implemented"))
    }

    fn deserialize_char<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_char((self.0.unchecked_into::<Number>().as_f64().unwrap() as u8) as char)
    }

    // Serde can deserialize `visit_unit` into `None`, but can't deserialize arbitrary value
    // as `Some`, so we need to provide own simple implementation.
    fn deserialize_option<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        if let Ok(arr) = self.0.dyn_into::<Array>() {
            visitor.visit_some(Into::<Deserializer>::into(arr.get(1)))
        } else {
            visitor.visit_none()
        }
    }

    fn deserialize_newtype_struct<V: de::Visitor<'de>>(
        self,
        _name: &'static str,
        _visitor: V,
    ) -> Result<V::Value> {
        Err(Error::custom(
            "Deserializing newtype structus is not implemented",
        ))
    }

    fn deserialize_seq<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        let arr = self.0.unchecked_into::<Array>();
        visitor.visit_seq(SeqDeserializer::new(
            arr.iter().skip(1).map(Deserializer::from),
        ))
    }

    fn deserialize_tuple<V: de::Visitor<'de>>(self, _len: usize, visitor: V) -> Result<V::Value> {
        self.deserialize_seq(visitor)
    }

    fn deserialize_tuple_struct<V: de::Visitor<'de>>(
        self,
        _name: &'static str,
        _len: usize,
        _visitor: V,
    ) -> Result<V::Value> {
        Err(Error::custom(
            "Deserializing tuple structs is not implemented",
        ))
    }

    fn deserialize_map<V: de::Visitor<'de>>(self, _visitor: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing maps is not implemented"))
    }

    fn deserialize_struct<V: de::Visitor<'de>>(
        self,
        _name: &'static str,
        fields: &'static [&'static str],
        visitor: V,
    ) -> Result<V::Value> {
        let arr = self.0.unchecked_into::<Array>();
        visitor.visit_map(ObjectAccess::new(arr, fields))
    }

    fn deserialize_enum<V: de::Visitor<'de>>(
        self,
        _: &'static str,
        _: &'static [&'static str],
        _: V,
    ) -> Result<V::Value> {
        Err(Error::custom("Deserializing enums is not implemented"))
    }

    fn deserialize_ignored_any<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        visitor.visit_unit()
    }

    fn deserialize_bytes<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        self.deserialize_byte_buf(visitor)
    }

    fn deserialize_byte_buf<V: de::Visitor<'de>>(self, visitor: V) -> Result<V::Value> {
        if let Some(bytes) = self.as_bytes() {
            visitor.visit_byte_buf(bytes)
        } else {
            Err(Error::custom("Type error while deserializing bytes"))
        }
    }

    fn is_human_readable(&self) -> bool {
        true
    }
}

impl<'de> de::VariantAccess<'de> for Deserializer {
    type Error = Error;

    fn unit_variant(self) -> Result<()> {
        Err(Error::custom("Deserializing variants is not implemented"))
    }

    fn newtype_variant_seed<T: de::DeserializeSeed<'de>>(self, _: T) -> Result<T::Value> {
        Err(Error::custom("Deserializing variants is not implemented"))
    }

    fn tuple_variant<V: de::Visitor<'de>>(self, _: usize, _: V) -> Result<V::Value> {
        Err(Error::custom("Deserializing variants is not implemented"))
    }

    fn struct_variant<V: de::Visitor<'de>>(
        self,
        _: &'static [&'static str],
        _: V,
    ) -> Result<V::Value> {
        Err(Error::custom("Deserializing variants is not implemented"))
    }
}
