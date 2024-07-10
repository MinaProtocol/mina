//! OCaml types represented in Rust, these are zero-copy and incur no additional overhead

use crate::{sys, CamlError, Error, Raw, Runtime, Tag};

use core::{
    iter::{IntoIterator, Iterator},
    marker::PhantomData,
    mem, slice,
};

use crate::value::{FromValue, IntoValue, Size, Value};

/// A handle to a Rust value/reference owned by the OCaml heap.
///
/// This should only be used with values allocated with `alloc_final` or `alloc_custom`,
/// for abstract pointers see `Value::alloc_abstract_ptr` and `Value::abstract_ptr_val`
#[derive(Clone, PartialEq)]
#[repr(transparent)]
pub struct Pointer<'a, T>(pub Value, PhantomData<&'a T>);

unsafe impl<'a, T> IntoValue for Pointer<'a, T> {
    fn into_value(self, _rt: &Runtime) -> Value {
        self.0
    }
}

unsafe impl<'a, T> FromValue<'a> for Pointer<'a, T> {
    fn from_value(value: Value) -> Self {
        Pointer(value, PhantomData)
    }
}

unsafe extern "C" fn ignore(_: Raw) {}

impl<'a, T> Pointer<'a, T> {
    /// Allocate a new value with an optional custom finalizer and used/max
    ///
    /// This calls `caml_alloc_final` under-the-hood, which can has less than ideal performance
    /// behavior. In most cases you should prefer `Poiner::alloc_custom` when possible.
    pub fn alloc_final(
        x: T,
        finalizer: Option<unsafe extern "C" fn(Raw)>,
        used_max: Option<(usize, usize)>,
    ) -> Pointer<'a, T> {
        unsafe {
            let value = match finalizer {
                Some(f) => Value::alloc_final::<T>(f, used_max),
                None => Value::alloc_final::<T>(ignore, used_max),
            };
            let mut ptr = Pointer(value, PhantomData);
            ptr.set(x);
            ptr
        }
    }

    /// Allocate a `Custom` value
    pub fn alloc_custom(x: T) -> Pointer<'a, T>
    where
        T: crate::Custom,
    {
        unsafe {
            let mut ptr = Pointer(Value::alloc_custom::<T>(), PhantomData);
            ptr.set(x);
            ptr
        }
    }

    /// Drop pointer in place
    ///
    /// # Safety
    /// This should only be used when you're in control of the underlying value and want to drop
    /// it. It should only be called once.
    pub unsafe fn drop_in_place(mut self) {
        core::ptr::drop_in_place(self.as_mut_ptr())
    }

    /// Replace the inner value with the provided argument
    pub fn set(&mut self, x: T) {
        unsafe {
            core::ptr::write_unaligned(self.as_mut_ptr(), x);
        }
    }

    /// Access the underlying pointer
    pub fn as_ptr(&self) -> *const T {
        unsafe { self.0.custom_ptr_val() }
    }

    /// Access the underlying mutable pointer
    pub fn as_mut_ptr(&mut self) -> *mut T {
        unsafe { self.0.custom_ptr_val_mut() }
    }
}

impl<'a, T> AsRef<T> for Pointer<'a, T> {
    fn as_ref(&self) -> &T {
        unsafe { &*self.as_ptr() }
    }
}

impl<'a, T> AsMut<T> for Pointer<'a, T> {
    fn as_mut(&mut self) -> &mut T {
        unsafe { &mut *self.as_mut_ptr() }
    }
}

/// `Array<A>` wraps an OCaml `'a array` without converting it to Rust
#[derive(Clone, PartialEq)]
#[repr(transparent)]
pub struct Array<'a, T: IntoValue + FromValue<'a>>(Value, PhantomData<&'a T>);

unsafe impl<'a, T: IntoValue + FromValue<'a>> IntoValue for Array<'a, T> {
    fn into_value(self, _rt: &Runtime) -> Value {
        self.0
    }
}

unsafe impl<'a, T: IntoValue + FromValue<'a>> FromValue<'a> for Array<'a, T> {
    fn from_value(value: Value) -> Self {
        Array(value, PhantomData)
    }
}

impl<'a> Array<'a, f64> {
    /// Set value to double array
    pub fn set_double(&mut self, i: usize, f: f64) -> Result<(), Error> {
        if i >= self.len() {
            return Err(CamlError::ArrayBoundError.into());
        }

        if !self.is_double_array() {
            return Err(Error::NotDoubleArray);
        }

        unsafe {
            self.set_double_unchecked(i, f);
        };

        Ok(())
    }

    /// Set value to double array without bounds checking
    ///
    /// # Safety
    /// This function performs no bounds checking
    #[inline]
    pub unsafe fn set_double_unchecked(&mut self, i: usize, f: f64) {
        let ptr = ((self.0).raw().0 as *mut f64).add(i);
        *ptr = f;
    }

    /// Get a value from a double array
    pub fn get_double(&self, i: usize) -> Result<f64, Error> {
        if i >= self.len() {
            return Err(CamlError::ArrayBoundError.into());
        }
        if !self.is_double_array() {
            return Err(Error::NotDoubleArray);
        }

        Ok(unsafe { self.get_double_unchecked(i) })
    }

    /// Get a value from a double array without checking if the array is actually a double array
    ///
    /// # Safety
    ///
    /// This function does not perform bounds checking
    #[inline]
    pub unsafe fn get_double_unchecked(&self, i: usize) -> f64 {
        *(self.0.raw().0 as *mut f64).add(i)
    }
}

impl<'a, T: IntoValue + FromValue<'a>> Array<'a, T> {
    /// Allocate a new Array
    pub unsafe fn alloc(n: usize) -> Array<'a, T> {
        let x = Value::alloc(n, Tag(0));
        Array(x, PhantomData)
    }

    /// Check if Array contains only doubles, if so `get_double` and `set_double` should be used
    /// to access values
    pub fn is_double_array(&self) -> bool {
        unsafe { sys::caml_is_double_array(self.0.raw().0) == 1 }
    }

    /// Array length
    pub fn len(&self) -> usize {
        unsafe { sys::caml_array_length(self.0.raw().0) }
    }

    /// Returns true when the array is empty
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Set array index
    pub unsafe fn set(&mut self, rt: &Runtime, i: usize, v: T) -> Result<(), Error> {
        if i >= self.len() {
            return Err(CamlError::ArrayBoundError.into());
        }
        self.set_unchecked(rt, i, v);
        Ok(())
    }

    /// Set array index without bounds checking
    ///
    /// # Safety
    ///
    /// This function does not perform bounds checking
    #[inline]
    pub unsafe fn set_unchecked(&mut self, rt: &Runtime, i: usize, v: T) {
        self.0.store_field(rt, i, v);
    }

    /// Get array index
    pub fn get(&'a self, i: usize) -> Result<T, Error> {
        if i >= self.len() {
            return Err(CamlError::ArrayBoundError.into());
        }
        Ok(unsafe { self.get_unchecked(i) })
    }

    /// Get array index without bounds checking
    ///
    /// # Safety
    ///
    /// This function does not perform bounds checking
    #[inline]
    pub unsafe fn get_unchecked(&'a self, i: usize) -> T {
        FromValue::from_value(self.0.field(i))
    }

    #[doc(hidden)]
    pub fn as_slice(&self) -> &[Raw] {
        unsafe { self.0.slice() }
    }

    #[doc(hidden)]
    pub fn as_mut_slice(&mut self) -> &mut [Raw] {
        unsafe { self.0.slice_mut() }
    }

    /// Array as `Vec`
    #[cfg(not(feature = "no-std"))]
    pub fn into_vec(self) -> Vec<T> {
        FromValue::from_value(self.0)
    }

    /// Array as `Vec`
    #[cfg(not(feature = "no-std"))]
    pub fn as_vec(&'a self) -> Vec<T> {
        let mut dest = Vec::new();
        let len = self.len();

        for i in 0..len {
            unsafe { dest.push(self.get_unchecked(i)) }
        }

        dest
    }
}

/// `List<A>` wraps an OCaml `'a list` without converting it to Rust, this introduces no
/// additional overhead compared to a `Value` type
#[derive(Clone, PartialEq)]
#[repr(transparent)]
pub struct List<'a, T: 'a + IntoValue + FromValue<'a>>(Value, PhantomData<&'a T>);

unsafe impl<'a, T: IntoValue + FromValue<'a>> IntoValue for List<'a, T> {
    fn into_value(self, _rt: &Runtime) -> Value {
        self.0
    }
}

unsafe impl<'a, T: IntoValue + FromValue<'a>> FromValue<'a> for List<'a, T> {
    fn from_value(value: Value) -> Self {
        List(value, PhantomData)
    }
}

impl<'a, T: IntoValue + FromValue<'a>> List<'a, T> {
    /// An empty list
    #[inline(always)]
    pub fn empty() -> List<'a, T> {
        List(Value::unit(), PhantomData)
    }

    /// Returns the number of items in `self`
    pub unsafe fn len(&self) -> usize {
        let mut length = 0;
        let mut tmp = self.0.raw();
        while tmp.0 != sys::EMPTY_LIST {
            let p = sys::field(tmp.0, 1);
            if p.is_null() {
                break;
            }
            tmp = (*p).into();
            length += 1;
        }
        length
    }

    /// Returns true when the list is empty
    pub fn is_empty(&self) -> bool {
        self.0 == Self::empty().0
    }

    /// Add an element to the front of the list returning the new list
    #[must_use]
    #[allow(clippy::should_implement_trait)]
    pub unsafe fn add(self, rt: &Runtime, v: T) -> List<'a, T> {
        let item = v.into_value(rt);
        let mut dest = Value::alloc(2, Tag(0));
        dest.store_field(rt, 0, item);
        dest.store_field(rt, 1, self.0);
        List(dest, PhantomData)
    }

    /// List head
    pub fn hd(&self) -> Option<Value> {
        if self.is_empty() {
            return None;
        }

        unsafe { Some(self.0.field(0)) }
    }

    /// List tail
    pub fn tl(&self) -> List<'a, T> {
        if self.is_empty() {
            return Self::empty();
        }

        unsafe { List(self.0.field(1), PhantomData) }
    }

    #[cfg(not(feature = "no-std"))]
    /// List as `Vec`
    pub fn into_vec(self) -> Vec<T> {
        self.into_iter().map(T::from_value).collect()
    }

    #[cfg(not(feature = "no-std"))]
    /// List as `LinkedList`
    pub fn into_linked_list(self) -> std::collections::LinkedList<T> {
        FromValue::from_value(self.0)
    }

    /// List iterator
    #[allow(clippy::should_implement_trait)]
    pub fn into_iter(self) -> ListIterator<'a> {
        ListIterator {
            inner: self.0,
            _marker: PhantomData,
        }
    }
}

impl<'a, T: IntoValue + FromValue<'a>> IntoIterator for List<'a, T> {
    type Item = Value;
    type IntoIter = ListIterator<'a>;

    fn into_iter(self) -> Self::IntoIter {
        List::into_iter(self)
    }
}

/// List iterator.
pub struct ListIterator<'a> {
    inner: Value,
    _marker: PhantomData<&'a Value>,
}

impl<'a> Iterator for ListIterator<'a> {
    type Item = Value;

    fn next(&mut self) -> Option<Self::Item> {
        if self.inner.raw().0 != sys::UNIT {
            unsafe {
                let val = self.inner.field(0);
                self.inner = self.inner.field(1);
                Some(val)
            }
        } else {
            None
        }
    }
}

/// `bigarray` contains wrappers for OCaml `Bigarray` values. These types can be used to transfer arrays of numbers between Rust
/// and OCaml directly without the allocation overhead of an `array` or `list`
pub mod bigarray {
    use super::*;
    use crate::sys::bigarray;

    /// Bigarray kind
    pub trait Kind {
        /// Array item type
        type T: Clone + Copy;

        /// OCaml bigarray type identifier
        fn kind() -> i32;
    }

    macro_rules! make_kind {
        ($t:ty, $k:ident) => {
            impl Kind for $t {
                type T = $t;

                fn kind() -> i32 {
                    bigarray::Kind::$k as i32
                }
            }
        };
    }

    make_kind!(u8, UINT8);
    make_kind!(i8, SINT8);
    make_kind!(u16, UINT16);
    make_kind!(i16, SINT16);
    make_kind!(f32, FLOAT32);
    make_kind!(f64, FLOAT64);
    make_kind!(i64, INT64);
    make_kind!(i32, INT32);
    make_kind!(char, CHAR);

    /// OCaml Bigarray.Array1 type, this introduces no
    /// additional overhead compared to a `Value` type
    #[repr(transparent)]
    #[derive(Clone, PartialEq)]
    pub struct Array1<T>(Value, PhantomData<T>);

    unsafe impl<'a, T> crate::FromValue<'a> for Array1<T> {
        fn from_value(value: Value) -> Array1<T> {
            Array1(value, PhantomData)
        }
    }

    unsafe impl<T> crate::IntoValue for Array1<T> {
        fn into_value(self, _rt: &Runtime) -> Value {
            self.0
        }
    }

    impl<T: Copy + Kind> Array1<T> {
        /// Array1::of_slice is used to convert from a slice to OCaml Bigarray,
        /// the `data` parameter must outlive the resulting bigarray or there is
        /// no guarantee the data will be valid. Use `Array1::from_slice` to clone the
        /// contents of a slice.
        pub unsafe fn of_slice(data: &mut [T]) -> Array1<T> {
            let x = Value::new(bigarray::caml_ba_alloc_dims(
                T::kind() | bigarray::Managed::EXTERNAL as i32,
                1,
                data.as_mut_ptr() as bigarray::Data,
                data.len() as sys::Intnat,
            ));
            Array1(x, PhantomData)
        }

        /// Convert from a slice to OCaml Bigarray, copying the array. This is the implemtation
        /// used by `Array1::from` for slices to avoid any potential lifetime issues
        #[cfg(not(feature = "no-std"))]
        pub unsafe fn from_slice(data: impl AsRef<[T]>) -> Array1<T> {
            let x = data.as_ref();
            let mut arr = Array1::<T>::create(x.len());
            let data = arr.data_mut();
            data.copy_from_slice(x);
            arr
        }

        /// Create a new OCaml `Bigarray.Array1` with the given type and size
        pub unsafe fn create(n: Size) -> Array1<T> {
            let data = { bigarray::malloc(n * mem::size_of::<T>()) };
            let x = Value::new(bigarray::caml_ba_alloc_dims(
                T::kind() | bigarray::Managed::EXTERNAL as i32,
                1,
                data as bigarray::Data,
                n as sys::Intnat,
            ));
            Array1(x, PhantomData)
        }

        /// Returns the number of items in `self`
        pub fn len(&self) -> Size {
            unsafe {
                let ba = self.0.custom_ptr_val::<bigarray::Bigarray>();
                let dim = slice::from_raw_parts((*ba).dim.as_ptr() as *const usize, 1);
                dim[0]
            }
        }

        /// Returns true when `self.len() == 0`
        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }

        /// Get underlying data as Rust slice
        pub fn data(&self) -> &[T] {
            unsafe {
                let ba = self.0.custom_ptr_val::<bigarray::Bigarray>();
                slice::from_raw_parts((*ba).data as *const T, self.len())
            }
        }

        /// Get underlying data as mutable Rust slice
        pub fn data_mut(&mut self) -> &mut [T] {
            unsafe {
                let ba = self.0.custom_ptr_val::<bigarray::Bigarray>();
                slice::from_raw_parts_mut((*ba).data as *mut T, self.len())
            }
        }
    }

    #[cfg(all(feature = "bigarray-ext", not(feature = "no-std")))]
    pub use super::bigarray_ext::*;
}

#[cfg(all(feature = "bigarray-ext", not(feature = "no-std")))]
pub(crate) mod bigarray_ext {
    use ndarray::{ArrayView2, ArrayView3, ArrayViewMut2, ArrayViewMut3, Dimension};

    use core::{marker::PhantomData, mem, ptr, slice};

    use crate::{
        bigarray::Kind,
        sys::{self, bigarray},
        FromValue, IntoValue, Runtime, Value,
    };

    /// OCaml Bigarray.Array2 type, this introduces no
    /// additional overhead compared to a `Value` type
    #[repr(transparent)]
    #[derive(Clone, PartialEq)]
    pub struct Array2<T>(Value, PhantomData<T>);

    impl<T: Copy + Kind> Array2<T> {
        /// Returns array view
        pub fn view(&self) -> ArrayView2<T> {
            let ba = unsafe { self.0.custom_ptr_val::<bigarray::Bigarray>() };
            unsafe { ArrayView2::from_shape_ptr(self.shape(), (*ba).data as *const T) }
        }

        /// Returns mutable array view
        pub fn view_mut(&mut self) -> ArrayViewMut2<T> {
            let ba = unsafe { self.0.custom_ptr_val::<bigarray::Bigarray>() };
            unsafe { ArrayViewMut2::from_shape_ptr(self.shape(), (*ba).data as *mut T) }
        }

        /// Returns the shape of `self`
        pub fn shape(&self) -> (usize, usize) {
            let dim = self.dim();
            (dim[0], dim[1])
        }

        /// Returns the number of items in `self`
        pub fn len(&self) -> usize {
            let dim = self.dim();
            dim[0] * dim[1]
        }

        /// Returns true when the list is empty
        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }

        fn dim(&self) -> &[usize] {
            let ba = unsafe { self.0.custom_ptr_val::<bigarray::Bigarray>() };
            unsafe { slice::from_raw_parts((*ba).dim.as_ptr() as *const usize, 2) }
        }
    }

    unsafe impl<'a, T> FromValue<'a> for Array2<T> {
        fn from_value(value: Value) -> Array2<T> {
            Array2(value, PhantomData)
        }
    }

    unsafe impl<T> IntoValue for Array2<T> {
        fn into_value(self, _rt: &Runtime) -> Value {
            self.0
        }
    }

    impl<T: Copy + Kind> Array2<T> {
        /// Create a new OCaml `Bigarray.Array2` with the given type and shape
        pub unsafe fn create(dim: ndarray::Ix2) -> Array2<T> {
            let data = bigarray::malloc(dim.size() * mem::size_of::<T>());
            let x = Value::new(bigarray::caml_ba_alloc_dims(
                T::kind() | bigarray::Managed::EXTERNAL as i32,
                2,
                data as bigarray::Data,
                dim[0] as sys::Intnat,
                dim[1] as sys::Intnat,
            ));
            Array2(x, PhantomData)
        }

        /// Create Array2 from ndarray
        pub unsafe fn from_ndarray(data: ndarray::Array2<T>) -> Array2<T> {
            let dim = data.raw_dim();
            let array = Array2::create(dim);
            let ba = { array.0.custom_ptr_val::<bigarray::Bigarray>() };
            {
                ptr::copy_nonoverlapping(data.as_ptr(), (*ba).data as *mut T, dim.size());
            }
            array
        }
    }

    /// OCaml Bigarray.Array3 type, this introduces no
    /// additional overhead compared to a `Value` type
    #[repr(transparent)]
    #[derive(Clone, PartialEq)]
    pub struct Array3<T>(Value, PhantomData<T>);

    impl<T: Copy + Kind> Array3<T> {
        /// Returns array view
        pub fn view(&self) -> ArrayView3<T> {
            let ba = unsafe { self.0.custom_ptr_val::<bigarray::Bigarray>() };
            unsafe { ArrayView3::from_shape_ptr(self.shape(), (*ba).data as *const T) }
        }

        /// Returns mutable array view
        pub fn view_mut(&mut self) -> ArrayViewMut3<T> {
            let ba = unsafe { self.0.custom_ptr_val::<bigarray::Bigarray>() };
            unsafe { ArrayViewMut3::from_shape_ptr(self.shape(), (*ba).data as *mut T) }
        }

        /// Returns the shape of `self`
        pub fn shape(&self) -> (usize, usize, usize) {
            let dim = self.dim();
            (dim[0], dim[1], dim[2])
        }

        /// Returns the number of items in `self`
        pub fn len(&self) -> usize {
            let dim = self.dim();
            dim[0] * dim[1] * dim[2]
        }

        /// Returns true when the list is empty
        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }

        fn dim(&self) -> &[usize] {
            let ba = unsafe { self.0.custom_ptr_val::<bigarray::Bigarray>() };
            unsafe { slice::from_raw_parts((*ba).dim.as_ptr() as *const usize, 3) }
        }
    }

    unsafe impl<'a, T> FromValue<'a> for Array3<T> {
        fn from_value(value: Value) -> Array3<T> {
            Array3(value, PhantomData)
        }
    }

    unsafe impl<T> IntoValue for Array3<T> {
        fn into_value(self, _rt: &Runtime) -> Value {
            self.0
        }
    }

    impl<T: Copy + Kind> Array3<T> {
        /// Create a new OCaml `Bigarray.Array3` with the given type and shape
        pub unsafe fn create(dim: ndarray::Ix3) -> Array3<T> {
            let data = { bigarray::malloc(dim.size() * mem::size_of::<T>()) };
            let x = Value::new(bigarray::caml_ba_alloc_dims(
                T::kind() | bigarray::Managed::MANAGED as i32,
                3,
                data,
                dim[0] as sys::Intnat,
                dim[1] as sys::Intnat,
                dim[2] as sys::Intnat,
            ));
            Array3(x, PhantomData)
        }

        /// Create Array3 from ndarray
        pub unsafe fn from_ndarray(data: ndarray::Array3<T>) -> Array3<T> {
            let dim = data.raw_dim();
            let array = Array3::create(dim);
            let ba = { array.0.custom_ptr_val::<bigarray::Bigarray>() };
            {
                ptr::copy_nonoverlapping(data.as_ptr(), (*ba).data as *mut T, dim.size());
            }
            array
        }
    }
}
