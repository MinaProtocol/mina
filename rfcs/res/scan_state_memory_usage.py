#!/usr/bin/env python

# Sorry for the style of this python code, these are just some calculations
# which got quickly converted to a script.

import sys

Word = 8 # system word size (assumed to be 64-bits/8-bytes for purposes of these numbers)
Nonce = 4
Amount = 8
Fee = 8
Memo = 8
TxnProofType = 8
LedgerDepth = 30

Field = 95
Hash = Field
Group = 3 * Field # ==> 285
Pk = Field # ==> 95
Sig = 2 * Field # ==> 190
Proof = 5 * Group # ==> 1425
Sok = Fee + Pk # ==> 103

Account = 2*Pk + Amount + Nonce + Hash
Txn = 2*Pk + Sig + 2*Amount + Memo + Nonce # ==> 404
Undo = 2*Hash + 2*Pk + Txn # ==> 784

TxnStatement = 4*Hash + Amount + Fee + TxnProofType # ==> 404
TxnWitness = 2*(2*LedgerDepth*Hash + Account) # ==> 5914
Base = Undo + TxnStatement + TxnWitness # ==> 7102
Merge = TxnStatement + Proof + Sok # ==> 1932
FullLeaf = Base + 5*Word # ==> 1228
EmptyLeaf = 3 * Word # ==> 24
FullBranch = 2*Merge + 7*Word # ==> 3920
EmptyBranch = 5*Word # ==> 40

def NumberOfBranches(M, T):
    return T * (2**M - 1)

def NumberOfFullBranches(M, T, D):
    acc = 0
    for i in range(1, M+1):
        for j in range(1, i+1):
            acc += (2**(M-j)) * (D+1)
    return acc

def NumberOfEmptyBranches(M, T, D):
    return NumberOfBranches(M, T) - NumberOfFullBranches(M, T, D)

def NumberOfFullLeaves(M, T):
    return (T-1) * 2**M

def NumberOfEmptyLeaves(M):
    return 2**M

def ScanState(M, T, D):
    TreeStructureOverhead = T * ((2**M-1) * Word)
    FullBranches = NumberOfFullBranches(M, T, D) * FullBranch
    EmptyBranches = NumberOfEmptyBranches(M, T, D) * EmptyBranch
    FullLeaves = NumberOfFullLeaves(M, T) * FullLeaf
    EmptyLeaves = NumberOfEmptyLeaves(M) * EmptyLeaf
    return TreeStructureOverhead + FullBranches + EmptyBranches + FullLeaves + EmptyLeaves

if __name__ == '__main__':
    if(len(sys.argv) < 3):
        print('not enough arguments')
        exit(1)

    M = int(sys.argv[1])
    D = int(sys.argv[2])
    T = (M+1) * (D+1) + 1

    print('M = %d' % M)
    print('T = %d' % T)
    print('D = %d' % D)

    print('NumberOfFullBranches = %d' % NumberOfFullBranches(M, T, D))
    print('NumberOfEmptyBranches = %d' % NumberOfEmptyBranches(M, T, D))
    print('Scan State Size = %d' % ScanState(M, T, D))
