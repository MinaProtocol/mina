%start <char list> main

%%

main:
| c = TOKEN EOF { [c] }
| c = TOKEN xs = main  { c :: xs }
