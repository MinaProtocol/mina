root() {
    dirname "$0"
}

charts() {
    echo "$(root)/.."
}

resources() {
    echo "$(root)/resources"
}

resource() {
    echo "$(resources)/$1"
}

values_dir() {
    echo "$(root)/${VALUES_DIR:-values}"
}

values() {
    echo "$(values_dir)/$1.yaml"
}

kubectl_ns() {
    kubectl config view --minify --output 'jsonpath={..namespace}'
}
