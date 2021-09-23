#!/usr/bin/env bash

USER=o

ufw disable

useradd -s /bin/bash -d /home/$USER -m -G sudo $USER
echo -e "k\nk" | passwd $USER

cat <<EOT >> launch.sh
#!/usr/bin/env bash

. ~/.nix-profile/etc/profile.d/nix.sh
nix-channel --add https://nixos.org/channels/nixos-20.09 nixpkgs && nix-channel --update

export MINA_LIBP2P_HELPER_PATH=./helper
nix-shell --run './mina "$@"'
EOT

chmod +x launch.sh

mkdir -p -m 0755 /nix && chown -R $USER /nix

cp -R .ssh /home/$USER/.ssh
mv {mina,helper,launch.sh,shell.nix,genesis_ledgers} /home/$USER
curl -L https://nixos.org/nix/install > /home/$USER/setup-nix.sh
chmod +x /home/$USER/setup-nix.sh
chown -R $USER /home/$USER/{mina,helper,launch.sh,shell.nix,.ssh,setup-nix.sh,genesis_ledgers}

su -c "sh -c 'cd ~; ./setup-nix.sh'" $USER
