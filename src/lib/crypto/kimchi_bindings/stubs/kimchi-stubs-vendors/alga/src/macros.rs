// Copyright 2014 The Algebra Developers. For a full listing of the authors,
// refer to the AUTHORS file at the top-level directory of this distribution.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Implements empty traits aka marker traits for types provided.
/// # Examples
///
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # fn main() {}
/// trait Marker {}
/// struct Struct;
/// impl_marker!(Marker; u32; Struct);
/// ```
/// ```
/// # #[macro_use]
/// # extern crate alga;
/// # use std::fmt::Debug;
/// # fn main() {}
/// trait Marker<T: Debug> {}
/// struct Struct<T>(T);
/// impl_marker!(Marker<T>; Struct<T> where T: Debug);
/// ```
macro_rules! impl_marker(
    // Finds the generic parameters of the type and implements the trait for it
    (@para_rec
        [$tra1t:ty, ($($clause:tt)+), ($($type_constr:tt)*)]
        (< $($params:tt)*)
    ) => {
        impl< $($params)* $tra1t for $($type_constr)*< $($params)*
            where $($clause)+
        {}
    };
    // Munches some token trees for searching generic parameters of the type
    (@para_rec
        [$tra1t:ty, ($($clause:tt)+), ($($prev:tt)*)]
        ($cur:tt $($rest:tt)*)
    ) => {
        impl_marker!(@para_rec
            [$tra1t, ($($clause)+), ($($prev)* $cur)]
            ($($rest)*)
        );
    };
    // Handles the trailing separator after where clause
    (@where_rec
        [$tra1t:ty, ($($typ3:tt)+), ($($clause:tt)+)]
        ($(;)*)
    ) => {
        impl_marker!(@para_rec
            [$tra1t, ($($clause)+), ()]
            ($($typ3)+)
        );
    };
    // Implements the trait for the generic type and continues searching other types
    (@where_rec
        [$tra1t:ty, ($($typ3:tt)+), ($($clause:tt)+)]
        (; $($rest:tt)+)
    ) => {
        impl_marker!(@para_rec
            [$tra1t, ($($clause)+), ()]
            ($($typ3)+)
        );
        impl_marker!(@rec
            [$tra1t, ()]
            ($($rest)+)
        );
    };
    // Munches some token trees for searching the end of the where clause
    (@where_rec
        [$tra1t:ty, ($($typ3:tt)+), ($($prev:tt)*)]
        ($cur:tt $($rest:tt)*)
    ) => {
        impl_marker!(@where_rec
            [$tra1t, ($($typ3)+), ($($prev)* $cur)]
            ($($rest)*)
        );
    };
    // Handles the trailing separator for non-generic type and implements the trait
    (@rec
        [$tra1t:ty, ($($typ3:tt)*)]
        ($(;)*)
    ) => {
        impl $tra1t for $($typ3)* { }
    };
    // Implements the trait for the non-generic type and continues searching other types
    (@rec
        [$tra1t:ty, ($($typ3:tt)*)]
        (; $($rest:tt)+)
    ) => {
        impl $tra1t for $($typ3)* { }
        impl_marker!(@rec
            [$tra1t, ()]
            ($($rest)+)
        );
    };
    // Detects that there is indeed a where clause for the type and tries to find where it ends.
    (@rec
        [$tra1t:ty, ($($prev:tt)+)]
        (where $($rest:tt)+)
    ) => {
        impl_marker!(@where_rec
            [$tra1t, ($($prev)+), ()]
            ($($rest)+)
        );
    };
    // Munches some token trees for detecting if we have where clause or not
    (@rec
        [$tra1t:ty, ($($prev:tt)*)]
        ($cur:tt $($rest:tt)*)
    ) => {
        impl_marker!(@rec
            [$tra1t, ($($prev)* $cur)]
            ($($rest)*)
        );
    };
    // Entry point to the macro
    ($tra1t:ty; $($rest:tt)+) => {
        impl_marker!(@rec
            [$tra1t, ()]
            ($($rest)+)
        );
    };
);

macro_rules! impl_ident {
    ($M:ty; $V:expr; $($T:ty),* $(,)*) => {
        $(impl Identity<$M> for $T { #[inline] fn identity() -> $T {$V} })+
    }
}

macro_rules! impl_approx_eq {
    ($V:expr; $($T:ty),* $(,)*) => {
        $(impl ApproxEq for $T {
            type Eps = $T;
            #[inline]
            fn default_epsilon() -> Self::Eps { $V }
            #[inline]
            fn approx_eq_eps(&self, b: &$T, epsilon: &$T) -> bool {
                if self < b {
                    *b - *self <= *epsilon
                } else {
                    *self - *b <= *epsilon
                }
            }
        })+
    }
}
