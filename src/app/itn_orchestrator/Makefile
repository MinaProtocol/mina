tidy:
	cd src && go mod tidy

src/graphql_generated.go: genqlient.graphql schema.graphql
	cd src && go get github.com/Khan/genqlient/generate@v0.5.0 && go run github.com/Khan/genqlient ../genqlient.yaml

orchestrator: src/graphql_generated.go $(shell find src/ -type f)
	cd src/itn_orchestrator/ && go build -o ../../orchestrator

generator: src/graphql_generated.go $(shell find src/ -type f)
	cd src/generator/ && go build -o ../../generator

clean:
	rm -f orchestrator src/graphql_generated.go generator

test:
	cd src && go test

.PHONY: clean tidy test
