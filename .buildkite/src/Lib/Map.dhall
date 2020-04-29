let Entry = { Type =  \(value: Type) -> { mapKey : Text, mapValue : value } }
in
{ Entry = Entry, Type = \(value : Type) -> List (Entry.Type value) }

