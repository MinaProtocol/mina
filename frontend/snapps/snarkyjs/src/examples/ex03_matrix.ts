import { Field } from '../snarky';

/* Exercise 3:

Implement a function for matrix multiplication.
*/

type Matrix<A> = A[][];

/* Input: 
    m1: m x n matrix
    m2: n x k matrix
   Output: m x k matrix
*/
export function matMul(m1: Matrix<Field>, m2: Matrix<Field>) {
  console.assert(m1[0].length === m2.length);
  const m = m1.length;
  const n = m2.length;
  const k = m2[0].length;

  let res = [];
  for (let rowIndex = 0; rowIndex < m; ++rowIndex) {
    let row = [];
    for (let colIndex = 0; colIndex < k; ++colIndex) {
      let v = Field.zero;
      for (let i = 0; i < n; ++i) {
        v = v.add(m1[rowIndex][i].mul(m2[i][colIndex]))
      }
      row.push(v);
    }
    res.push(row);
  }

  return res;
}