%start <char list> main
%token <char> TOKEN
%token EOF

%%

main:
| c = TOKEN EOF { [c] }
| c = TOKEN xs = main  { c :: xs }
