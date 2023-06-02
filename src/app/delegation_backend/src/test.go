package delegation_backend

import (
	"encoding/json"
	"fmt"
)

// Define the initial version 1 of the data type
type MyDataV1 struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

// Add a version-specific method for version 1
func (d MyDataV1) Print() {
	fmt.Printf("ID: %d, Name: %s, Email: %s\n", d.ID, d.Name, d.Email)
}

// Define the version 2 of the data type by embedding the previous version
type MyDataV2 struct {
	MyDataV1
	Age   int    `json:"age"`
	Email string `json:"email,omitempty"`
}

// Add a version-specific method for version 2
func (d MyDataV2) Print() {
	fmt.Printf("ID: %d, Name: %s, Age: %d\n", d.ID, d.Name, d.Age)
}

func main() {
	// Create an instance of version 1
	dataV1 := MyDataV1{ID: 1, Name: "John", Email: "john@example.com"}

	// Use version 1 behavior
	dataV1.Print() // Output: ID: 1, Name: John, Email: john@example.com

	// Convert version 1 to JSON
	jsonV1, _ := json.Marshal(dataV1)
	fmt.Println(string(jsonV1)) // Output: {"id":1,"name":"John","email":"john@example.com"}

	// Create an instance of version 2 without the Email field
	dataV2 := MyDataV2{
		MyDataV1: MyDataV1{ID: 2, Name: "Jane", Email: ""},
		Age:      25,
	}

	// Use version 2 behavior
	dataV2.Print() // Output: ID: 2, Name: Jane, Age: 25

	// Convert version 2 to JSON
	jsonV2, _ := json.Marshal(dataV2)
	fmt.Println(string(jsonV2)) // Output: {"id":2,"name":"Jane","age":25}

	// Convert JSON back to version 2
	var restoredDataV2 MyDataV2
	json.Unmarshal(jsonV2, &restoredDataV2)

	// Use the restored version 2 data
	restoredDataV2.Print() // Output: ID: 2, Name: Jane, Age: 25
}
