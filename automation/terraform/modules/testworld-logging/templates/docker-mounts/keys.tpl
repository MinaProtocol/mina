cat > /root/secret_key.sh <<- "SCRIPT"
#!/bin/bash
mkdir -p /root/keys/
touch /root/keys/secret_key
echo "${key_value}" > /root/keys/secret_key
SCRIPT