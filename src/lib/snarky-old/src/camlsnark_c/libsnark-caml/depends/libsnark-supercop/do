mkdir -p build
cd build
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_verify/16/ref/*.c
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_verify/32/ref/*.c
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_verify/8/ref/*.c
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_core/aes128encrypt/openssl/*.c
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_hash/sha256/sphlib/*.c
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_hash/sha512/openssl/*.c
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_sign/ed25519/amd64-51-30k/*.c 
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/crypto_sign/ed25519/amd64-51-30k/*.s
gcc -c -Wall -m64 -O3 -fomit-frame-pointer -I../include/ ../src/randombytes.c
mkdir -p ../lib
ar r ../lib/libsupercop.a *.o
cd ..
