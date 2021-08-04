import * as Snarky from '../bindings/snarky.js';

/* @param x an n*m matrix, encoded as x[i][j] for row i column j.
 * @param y an o*n matrix, both encoded as y[i][j] for row i column j.
 * Returns an o*m matrix.
*/
let matrix_mul = function (n: number, m: number, o: number, x: Snarky.Field[][], y: Snarky.Field[][]): Snarky.Field[][] {
    var res: Snarky.Field[][] = [];
    /* Initialize output matrix */
    for (var i = 0; i < o; i++) {
        for (var j = 0; j < m; j++) {
            res[i][j] = Snarky.Field.zero;
        }
    }
    /* Compute the output matrix. */
    for (var i = 0; i < n; i++) {
        for (var j = 0; j < m; j++) {
            for (var k = 0; k < o; k++) {
                res[k][j] = res[k][j].add(x[i][j].mul(y[k][i]));
            }
        }
    }
    return res;
}

export function circuit(): Snarky.Field[][] {
    let n = 3;
    let m = 4;
    let o = 3;
    let x = Snarky.Circuit.witness(Snarky.Circuit.array(Snarky.Circuit.array<Snarky.Field>(Snarky.Field, m), n), () => {
        return [
            [Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random()],
            [Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random()],
            [Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random()]]
    });
    let y = Snarky.Circuit.witness(Snarky.Circuit.array(Snarky.Circuit.array<Snarky.Field>(Snarky.Field, o), m), () => {
        return [
            [Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random()],
            [Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random()],
            [Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random(), Snarky.Field.random()]]
    });
    return matrix_mul(n, m, o, x, y);
}
