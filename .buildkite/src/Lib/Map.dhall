-- Maps are lists of special "entry" records. This is made explicit here
let Entry = { Type =  \(value: Type) -> { mapKey : Text, mapValue : value } } in
{ Entry = Entry, Type = \(value : Type) -> List (Entry.Type value) }

