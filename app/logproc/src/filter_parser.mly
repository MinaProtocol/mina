%token <int> INT
%token <string> STRING
%token <Logger.Level.t> LEVEL_LITERAL
%token TRUE
%token FALSE
%token NULL
%token LEFT_PAREN
%token RIGHT_PAREN
%token PID
%token HOST
%token LEVEL
%token CARET
%token EQUAL
%token NOT_EQUAL
%token AND
%token OR
%token NOT
%token EOF

%left OR
%left AND

%nonassoc NOT

%start <Filter.t option> prog
%%

prog:
  | EOF      { None }
  | v = bool_expr EOF { Some v }
;

bool_expr:
  | TRUE { Filter.True }
  | FALSE { Filter.False }
  | v1 = sexp_expr; EQUAL; v2 = sexp_expr { Filter.Sexp_equal (v1, v2) }
  | v1 = sexp_expr; NOT_EQUAL; v2 = sexp_expr { Filter.Not (Filter.Sexp_equal (v1, v2)) }
  | LEFT_PAREN; v = bool_expr; RIGHT_PAREN { v }
  | b1 = bool_expr; AND; b2 = bool_expr { Filter.And (b1, b2) }
  | b1 = bool_expr; OR; b2 = bool_expr { Filter.Or (b1, b2) }
  | NOT; v = bool_expr { Filter.Not v }
  ;

sexp_expr:
  | LEFT_PAREN; v = sexp_expr; RIGHT_PAREN { v }
  | CARET; s = STRING { Filter.Attribute s }
  | s = STRING { Filter.String s }
  | n = INT { Filter.Int n }
  | NULL { Filter.Null }
  | HOST { Filter.Host }
  | PID { Filter.Pid }
  | LEVEL { Filter.Level }
  | l = LEVEL_LITERAL { Filter.Level_literal l }
  ;
