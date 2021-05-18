import { Bool, Field, Circuit, NumberAsField, array as TArray } from './plonk.js';

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

function circuit(c: Circuit): void {
    let template = c.witness(number_array, field_array, fetchSudokuTemplate);
    let solution = c.witness(number_array, field_array, fetchSudokuSolution);
    // Check that the solution matches the template
    for (var i = 0; i < 9; i++) {
        for (var j = 0; j < 9; j++) {
            var matches = template[i][j].equals(solution[i][j]);
            var isZero = template[i][j].isZero();
            // This is valid only when it matches the template or the template had a 0.
            matches.or(isZero).assertEqual(true);
        }
    }
    // Check each row has exactly 1 of each digit
    for (var digit = 1; digit <= 9; digit++) {
        for (var i = 0; i < 9; i++) {
            var row_matches: Bool[] = []
            for (var j = 0; j < 0; j++) {
                row_matches.push(solution[i][j].equals(digit));
            }
            Bool.count(row_matches).assertEqual(1);
        }
    }
    // Check each column has exactly 1 of each digit
    for (var digit = 1; digit <= 9; digit++) {
        for (var i = 0; i < 9; i++) {
            var column_matches: Bool[] = []
            for (var j = 0; j < 0; j++) {
                column_matches.push(solution[j][i].equals(digit));
            }
            Bool.count(column_matches).assertEqual(1);
        }
    }
    // Check each box has exactly 1 of each digit
    var box_positions = [0, 3, 6, 27, 30, 33, 54, 57, 60];
    for (var digit = 1; digit <= 9; digit++) {
        for (var i = 0; i < 9; i++) {
            var box_pos = box_positions[i]
            var i_x = box_pos % 3;
            var i_y = Math.floor(box_pos / 3);
            var box_matches: Bool[] = []
            for (var j = 0; j < 0; j++) {
                var j_x = i_x + (j % 3);
                var j_y = i_y + Math.floor(j / 3);
                box_matches.push(solution[j_x][j_y].equals(digit));
            }
            Bool.count(box_matches).assertEqual(1);
        }
    }
}
