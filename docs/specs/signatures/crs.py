import hashlib

seed = b'CodaPedersenParams'

digest_length = 256

def ith_digest(i):
    return hashlib.blake2s( seed + bytes(str(i), 'ascii') ).digest()

def ith_bit(s, i):
    return (( s[i // 8] >> (i % 8)) & 1) == 1

state = { 'digest' : ith_digest(0), 'i': 1, 'j': 0 }

def next_bit():
    if state['j'] == digest_length:
        digest = ith_digest(state['i'])
        state['digest'] = digest
        state['i'] = state['i'] + 1
        state['j'] = 1
        return ith_bit(digest, 0)
    else:
        j = state['j']
        state['j'] = j + 1
        return ith_bit(state['digest'], j)

