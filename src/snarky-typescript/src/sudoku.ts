import { Field, Circuit, NumberAsField, array as TArray } from './plonk.js';

// Get the sudoku template from somewhere. We use '0' to track unfilled cells.
const fetchSudokuTemplate = function (): number[][] {
    throw new Error("TODO");
}
// Get the solution to the sudoku from somewhere.
const fetchSudokuSolution = function (): number[][] {
    throw new Error("TODO");
}

const number_array = TArray(TArray(NumberAsField, 9), 9);
const field_array = TArray(TArray<Field>(Field, 9), 9);

function circuit(c: Circuit): Field[][] {
    let template = c.witness(number_array, field_array, fetchSudokuTemplate);
    let solution = c.witness(number_array, field_array, fetchSudokuTemplate);
    // Check that the solution matches the template
    for (var i = 0; i < 9; i++) {
        for (var j = 0; j < 9; j++) {
            var matches = template[i][j].equals(solution[i][j]);
            var isZero = template[i][j].isZero();
            matches.or(isZero).assertEqual(true);
        }
    }
    let n = 3;
    let m = 4;
    let o = 3;
    let x = c.witness(c.array(c.array<Field>(Field, m), n), function () {
        return [
            [Field.random(), Field.random(), Field.random(), Field.random()],
            [Field.random(), Field.random(), Field.random(), Field.random()],
            [Field.random(), Field.random(), Field.random(), Field.random()]]
    });
    let y = c.witness(c.array(c.array<Field>(Field, o), m), function () {
        return [
            [Field.random(), Field.random(), Field.random(), Field.random()],
            [Field.random(), Field.random(), Field.random(), Field.random()],
            [Field.random(), Field.random(), Field.random(), Field.random()]]
    });
    return matrix_mul(n, m, o, x, y);
}
