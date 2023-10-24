cat > /root/secret_key.sh <<- "SCRIPT"
#!/bin/bash
mkdir -p /root/keys/
touch /root/keys/secret_key
echo "EuAe4UNGID1bAid3qkYqa/PklM6mpy9laQzVA88nkqI=" > /root/keys/secret_key
SCRIPT