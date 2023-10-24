cat > /root/node_names.sh <<- "SCRIPT"
#!/bin/bash
mkdir -p /root/names-data/
touch /root/names-data/node_names.json
echo "{}" > /root/names-data/node_names.json
SCRIPT
