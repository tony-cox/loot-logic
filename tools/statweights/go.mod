module github.com/lootlogic/statweights

go 1.25.0

require (
	github.com/wowsims/forever v0.0.0
	google.golang.org/protobuf v1.36.10
)

require golang.org/x/exp v0.0.0-20250408133849-7e4ce0ab07d0 // indirect

// The sim checkout to build against. It must have its protobuf Go files generated (see README.md).
// Change the path to where your checkout is.
replace github.com/wowsims/forever => ../../../wowsims-forever
