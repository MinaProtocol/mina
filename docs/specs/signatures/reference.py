import hashlib
import binascii
import crs
import sys

a = 11
b = 0x7DA285E70863C79D56446237CE2E1468D14AE9BB64B2BB01B10E60A5D5DFE0A25714B7985993F62F03B22A9A3C737A1A1E0FCF2C43D7BF847957C34CCA1E3585F9A80A95F401867C4E80F4747FDE5ABA7505BA6FCF2485540B13DFC8468A
a_coeff = a
b_coeff = b

p = 0x1C4C62D92C41110229022EEE2CDADB7F997505B8FAFED5EB7E8F96C97D87307FDB925E8A0ED8D99D124D9A15AF79DB26C5C28C859A99B3EEBCA9429212636B9DFF97634993AA4D6C381BC3F0057974EA099170FA13A4FD90776E240000001
n = 0x1C4C62D92C41110229022EEE2CDADB7F997505B8FAFED5EB7E8F96C97D87307FDB925E8A0ED8D99D124D9A15AF79DB117E776F218059DB80F0DA5CB537E38685ACCE9767254A4638810719AC425F0E39D54522CDD119F5E9063DE245E8001
G =(0xB0D6E141836D261DBE17959758B33A19987126CB808DFA411854CF0A44C0F4962ECA2A213FFEAA770DAD44F59F260AC64C9FCB46DA65CBC9EEBE1CE9B83F91A64B685106D5F1E4A05DDFAE9B2E1A567E0E74C1B7FF94CC3F361FB1F064AA,
    0x30BD0DCB53B85BD013043029438966FFEC9438150AD06F59B4CC8DDA8BFF0FE5D3F4F63E46AC91576D1B4A15076774FEB51BA730F83FC9EB56E9BCC9233E031577A744C336E1EDFF5513BF5C9A4D234BCC4AD6D9F1B3FDF00E16446A8268)

N = 753

def legendre_symbol(a):
    ls = pow(a, (p - 1)//2, p)
    if ls == p - 1:
        return -1
    return ls

def prime_mod_sqrt(a):
    """
    Square root modulo prime number
    Solve the equation
        x^2 = a mod p
    and return list of x solution
    http://en.wikipedia.org/wiki/Tonelli-Shanks_algorithm
    """
    a %= p

    # Simple case
    if a == 0:
        return [0]
    if p == 2:
        return [a]

    # Check solution existence on odd prime
    if legendre_symbol(a) != 1:
        return []

    # Simple case
    if p % 4 == 3:
        x = pow(a, (p + 1)//4, p)
        return [x, p-x]

    # Factor p-1 on the form q * 2^s (with Q odd)
    q, s = p - 1, 0
    while q % 2 == 0:
        s += 1
        q //= 2

    # Select a z which is a quadratic non resudue modulo p
    z = 1
    while legendre_symbol(z) != -1:
        z += 1
    c = pow(z, q, p)

    # Search for a solution
    x = pow(a, (q + 1)//2, p)
    t = pow(a, q, p)
    m = s
    while t != 1:
        # Find the lowest i such that t^(2^i) = 1
        i, e = 0, 2
        for i in range(1, m):
            if pow(t, e, p) == 1:
                break
            e *= 2

        # Update next value to iterate
        b = pow(c, 2**(m - i - 1), p)
        x = (x * b) % p
        t = (t * b * b) % p
        c = (b * b) % p
        m = i

    return [x, p-x]

def random_field_elt():
    res = 0
    for i in range(N):
        res += crs.next_bit() * (2 ** i)
    if res < p:
        return res
    else:
        return random_field_elt()

def both_sqrt(y2):
    [y, negy] = prime_mod_sqrt(y2)
    return (y, negy) if y < negy else (negy, y)

def is_square(x):
    return legendre_symbol(x) == 1

def random_curve_point():
    x = random_field_elt()
    y2 = (x*x*x + a * x + b) % p

    if not is_square(y2):
        return random_curve_point()

    (y1, y2) = both_sqrt(y2)
    y = y1 if crs.next_bit() else y2
    return (x, y)

def point_add(P1, P2):
    if (P1 is None):
        return P2
    if (P2 is None):
        return P1
    if (P1[0] == P2[0] and P1[1] != P2[1]):
        return None
    if (P1 == P2):
        lam = ((3 * P1[0] * P1[0] + a) * pow(2 * P1[1], p - 2, p)) % p
    else:
        lam = ((P2[1] - P1[1]) * pow(P2[0] - P1[0], p - 2, p)) % p
    x3 = (lam * lam - P1[0] - P2[0]) % p
    return (x3, (lam * (P1[0] - x3) - P1[1]) % p)

def point_sixteen_times(P):
    P2 = point_add(P, P)
    P4 = point_add(P2, P2)
    P8 = point_add(P4, P4)
    return point_add(P8, P8)

def generate_pedersen_params():
    params0 = [ random_curve_point() for _ in range(10) ]
    print ('done generating base-points')
    params = []

    for P in params0:
        Q = P
        for _ in range(N // 4):
            params.append(Q)
            Q = point_sixteen_times(Q)
    print ('done generating all pedersen parameters')
    return params

params = generate_pedersen_params()

# p = 4x^2 + 1
# x =  2^13 * 3 * 5^2 * 7 * 812042190598814369278464271 * 14652487457434080047781531290587846082350961711966140037946846663231932006768257

def point_neg(P):
    return (P[0], p - P[1])

def point_mul(P, n):
    R = None
    for i in range(N):
        if ((n >> i) & 1):
            R = point_add(R, P)
        P = point_add(P, P)
    return R

def pedersen(ts):
    res = None
    for i, (b0, b1, b2) in enumerate(ts):
        Pi = params[i]

        n = 1 + b0 + 2 * b1
        if n == 1:
            Qi = Pi
        elif n == 2:
            Qi = point_add(Pi, Pi)
        elif n == 3:
            Qi = point_add(Pi, point_add(Pi, Pi))
        else:
            PP = point_add(Pi, Pi)
            Qi = point_add(PP, PP)
        res = point_add(res, Qi)
    return res[0]

def bytes_from_int(x):
    return x.to_bytes(95, byteorder="little")

def hash_blake2s_pedersen(ts):
    return hashlib.blake2s(bytes_from_int(pedersen(ts))).digest()

def bytes_from_point(P):
    return (b'\x03' if P[1] & 1 else b'\x02') + bytes_from_int(P[0])

def point_from_bytes(b):
    if b[0:1] in [b'\x02', b'\x03']:
        odd = b[0] - 0x02
    else:
        return None
    x = int_from_bytes(b[1:96])
    y_sq = (pow(x, 3, p) + a_coeff * x + b_coeff) % p
    if not is_square(y_sq):
        return None
    y0 = prime_mod_sqrt(y_sq)[0]
    y = p - y0 if y0 & 1 != odd else y0
    return [x, y]

def int_from_bytes(b):
    return int.from_bytes(b, byteorder="little")

def tryte_pad(bits):
    n = len(bits)
    bits = bits + ([] if n % 3 == 0 else [0 for _ in range(3 - (n % 3))])
    assert (len(bits) == 3 * ((n + 2)//3))
    return [ (bits[i], bits[i+1], bits[i + 2]) for i in range((n + 2) // 3) ]

def bits_from_int(x):
    return [ (x >> i) & 1 for i in range(N) ]

def trytes_from_int(x):
    return tryte_pad(bits_from_int(x))

def trytes_from_point(P):
    (x, y) = P
    return tryte_pad(bits_from_int(x) + [ y % 2 ])

def hash_blake2s(x):
    return hashlib.blake2s(x).digest()

def bytes_from_trytes(ts):
    bits = [ b for t in ts for b in t ]
    n = len(bits)
    bits = bits + ([] if n % 8 == 0 else [ 0 for _ in range(8 - n % 8) ])
    return bytes([
        b[i]
        + 2 * b[i+1]
        + 4 * b[i+2]
        + 8 * b[i+3]
        + 16 * b[i+4]
        + 32 * b[i+5]
        + 64 * b[i+6]
        + 128 * b[i+7] for i in range((n + 7) // 8) ])

def bits_from_bytes(bs):
    def bits_from_byte(b):
        return [ (b >> i) & 1 for i in range(8) ]

    return [b for by in bs for b in bits_from_byte(by)]

def trytes_from_bytes(bs):
    return tryte_pad(bits_from_bytes(bs))

def schnorr_sign(msg, seckey):
    if not (1 <= seckey <= n - 1):
        raise ValueError('The secret key must be an integer in the range 1..n-1.')
    k0 = int_from_bytes(
            hash_blake2s(bytes_from_int(seckey) + msg))
    if k0 == 0:
        raise RuntimeError('Failure. This happens only with negligible probability.')
    R = point_mul(G, k0)
    k = n - k0 if (R[1] % 2 != 0) else k0
    e = int_from_bytes(hash_blake2s_pedersen(
        trytes_from_int(R[0]) + 
        trytes_from_point(point_mul(G, seckey)) +
        trytes_from_bytes(msg)))
    return bytes_from_int(R[0]) + bytes_from_int((k + e * seckey) % n)

def schnorr_verify(msg, pubkey, sig):
    if len(pubkey) != 96:
        raise ValueError('The public key must be a 96-byte array.')
    if len(sig) != 190:
        raise ValueError('The signature must be a 190-byte array.')
    P = point_from_bytes(pubkey)
    if (P is None):
        return False
    r = int_from_bytes(sig[0:95])
    s = int_from_bytes(sig[95:190])
    if (r >= p or s >= n):
        return False
    e = int_from_bytes(hash_blake2s_pedersen(
        trytes_from_int(r) + trytes_from_point(P) + trytes_from_bytes(msg)))
    R = point_add(point_mul(G, s), point_mul(P, n - e))
    if R is None or (R[1] % 2 != 0) or R[0] != r:
        return False
    return True

if __name__ == '__main__':
    MSG = b'this is a test'
    KEY = random_field_elt()
    SIG = schnorr_sign(MSG, KEY)
    if schnorr_verify(MSG, bytes_from_point(point_mul(G, KEY)), SIG):
        print('Signature verified')
    else:
        print('Signature failed to verify')
        sys.exit(1)

