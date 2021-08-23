import { Poseidon, Field, Bool, Group, Circuit, Scalar } from '../snarky';
import { PrivateKey, PublicKey, Signature } from '../signature';

/* This file demonstrates the classes and functions available in snarky.js */

/* # Field */

/* The most basic type is Field, which is an element of a prime order field.
   The field is the [Pasta Fp field](https://electriccoin.co/blog/the-pasta-curves-for-halo-2-and-beyond/) 
   of order 28948022309329048855892746252171976963363056481941560715954676764349967630337 
*/

// You can initialize literal field elements with numbers, booleans, or decimal strings
const x0 : Field = new Field('37');
// Typescript has type inference, so type annotations are usually optional.
const x1 = new Field(37);
console.assert(x0.equals(x1).toBoolean());

// When initializing with booleans, true corresponds to the field element 1, and false corresponds to 0
const b = new Field(true);
console.assert(b.equals(Field.one).toBoolean());

/* You can perform arithmetic operations on field elements.
   The arithmetic methods can take any "fieldy" values as inputs: 
   Field, number, string, or boolean 
*/
const z = x0.mul(x1).add(b).div(234).square().neg().sub('67').add(false);

/* Field elements can be converted to their full, little endian binary representation. */
let bits : Bool[] = z.toBits();
console.log(bits.length);

/* If you know (or want to assert) that a field element fits in fewer bits, you can
   also unpack to a sequence of bits of a specified length. This is useful for doing
   range proofs for example. */
let smallFieldElt = new Field(23849);
let smallBits: Bool[] = smallFieldElt.toBits(32);
console.assert(smallBits.length === 32);

/* There are lots of other useful method on field elements, like comparison methods.
   Try right-clicking on the Field type, or and peeking the definition to see what they are.
  
   Or, you can look at the autocomplete list on a field element's methods. You can try typing
   
   z.

   to see the methods on `z : Field` for example.
*/

/* # Bool */

/* Another important type is Bool. The Bool type is the in-SNARK representation of booleans.
   They are different from normal booleans in that you cannot write an if-statement whose
   condition has type Bool. You need to use the Circuit.if function, which is like a value-level
   if (or something like a ternary expression). We will see how that works in a little.
*/

/* Bool values can be initialized using booleans. */

const b0 = new Bool(false);
const b1 = new Bool(true);

/* There are a number of methods available on Bool, like `and`, `or`, and `not`. */
const b3 : Bool = b0.and(b1.not()).or(b1);

/* The most important thing you can do with a Bool is use the `Circuit.if` function
   to conditionally select a value.

   `Circuit.if` has the type

   ```
   if<T>(
      b: Bool | boolean,
      x: T,
      y: T
   ): T
   ```

   `Circuit.if(b, x, y)` evaluates to `x` if `b` is true, and evalutes to `y` if `b` is false,
   so it works like a ternary if expression `b ? x : y`.

   The generic type T can be instantiated to primitive types like Bool, Field, or Group, or
   compound types like arrays (as long as the lengths are equal) or objects (as long as the keys
   match).
*/

const v : Field = Circuit.if(b0, x0, z);
/* b0 is false, so we expect v to be equal to z. */
console.assert(v.equals(z).toBoolean());

/* As mentioned, we can also use `Circuit.if` with compound types. */
const c = Circuit.if(
  b1, {
    foo: [x0, z],
    bar: { someFieldElt: x1, someBool: b1 }
  },{
    foo: [z, x0],
    bar: { someFieldElt: z, someBool: b0 }
  });

console.assert(c.bar.someFieldElt.equals(x1).toBoolean());

/* # Signature
*/

/* The standard library of snarkyJS comes with a Signature scheme.
   The message to be signed is an array of field elements, so any application level
   message data needs to be encoded as an array of field elements before being signed.
*/

let privKey : PrivateKey = PrivateKey.random();
let pubKey : PublicKey = PublicKey.fromPrivateKey(privKey);

let msg0 : Field[] = [ 0xBA5EBA11, 0x15, 0xBAD ].map(x => new Field(x));
let msg1 : Field[] = [ 0xFA1AFE1, 0xC0FFEE ].map(x => new Field(x));
let signature = Signature.create(privKey, msg0);

console.assert(signature.verify(pubKey, msg0).toBoolean());
console.assert(! signature.verify(pubKey, msg1).toBoolean());

/* # Group

  This type represents points on the [Pallas elliptic curve](https://electriccoin.co/blog/the-pasta-curves-for-halo-2-and-beyond/).

  It is a prime-order curve defined by the equation
  
  y^2 = x^3 + 5
*/

/* You can initialize elements as literals as follows: */
let g0 = new Group(-1, 2);
let g1 = new Group({x: -2, y: 2});

/* There is also a predefined generator. */
let g2 = Group.generator;

/* Points can be added, subtracted, and negated */
let g3 = g0.add(g1).neg().sub(g2);

/* Points can also be scaled by scalar field elements. Note that Field and Scalar
   are distinct and represent elements of distinct fields. */
let s0 : Scalar = Scalar.random();
let g4 : Group = g3.scale(s0);
console.log(Group.toJSON(g4));
