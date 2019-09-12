type ('field, 'bool) t =
  {field_elements: 'field array; bitstrings: 'bool list array}

let append t1 t2 =
  { field_elements= Array.append t1.field_elements t2.field_elements
  ; bitstrings= Array.append t1.bitstrings t2.bitstrings }
