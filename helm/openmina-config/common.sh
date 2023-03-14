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

values() {
    echo "$(root)/values/$1.yaml"
}
