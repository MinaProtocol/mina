"""
Sparse matrices in Scipy matching those we have in rust,
to make it easy to test our code.
"""

import numpy as np
import scipy.sparse

def mat1():
    indptr = np.array([0, 2, 4, 5, 6, 7])
    indices = np.array([2, 3, 3, 4, 2, 1, 3])
    data = np.array([3., 4., 2., 5., 5., 8., 7.])
    return scipy.sparse.csr_matrix((data, indices, indptr), shape=(5,5))

def mat1_csc():
    indptr = np.array([0, 0, 1, 3, 6, 7])
    indices = np.array([3, 0, 2, 0, 1, 4, 1])
    data = np.array([8.,  3.,  5.,  4.,  2.,  7.,  5.])
    return scipy.sparse.csc_matrix((data, indices, indptr), shape=(5,5))

def mat2():
    indptr = np.array([0,  4,  6,  6,  8, 10])
    indices = np.array([0, 1, 2, 4, 0, 3, 2, 3, 1, 2])
    data = np.array([6.,  7.,  3.,  3.,  8., 9.,  2.,  4.,  4.,  4.])
    return scipy.sparse.csr_matrix((data, indices, indptr), shape=(5,5))


def mat3():
    indptr = np.array([0, 2, 4, 5, 6, 7])
    indices = np.array([2, 3, 2, 3, 2, 1, 3])
    data = np.array([3., 4., 2., 5., 5., 8., 7.])
    return scipy.sparse.csr_matrix((data, indices, indptr), shape=(5,4))


def mat4():
    indptr = np.array([0,  4,  6,  6,  8, 10])
    indices = np.array([0, 1, 2, 4, 0, 3, 2, 3, 1, 2])
    data = np.array([6.,  7.,  3.,  3.,  8., 9.,  2.,  4.,  4.,  4.])
    return scipy.sparse.csc_matrix((data, indices, indptr), shape=(5,5))

def mat5():
    indptr = np.array([0, 5, 11, 14, 20, 22])
    indices = np.array([1, 2, 6, 7, 13, 3, 4, 6, 8, 13, 14, 7, 11, 13, 3, 8, 9,
                        10, 11, 14, 4, 12])
    data = np.array([4.8, 2., 3.7, 5.9, 6., 1.6, 0.3, 9.2, 9.9, 4.8, 6.1,
                     4.4, 6., 0.1, 7.2, 1., 1.4, 6.4, 2.8, 3.4, 5.5, 3.5])
    return scipy.sparse.csr_matrix((data, indices, indptr), shape=(5, 15))

def mat_dense1():
    return np.array([[0., 1., 2., 3., 4.],
                     [5., 6., 5., 4., 3.],
                     [4., 5., 4., 3., 2.],
                     [3., 4., 3., 2., 1.],
                     [1., 2., 1., 1., 0.]])

def mat_dense1_colmaj():
    res = np.zeros((5, 5)).T
    res.ravel(order="F")[:] = [0., 5., 4., 3., 1.,
                               1., 6., 5., 4., 2.,
                               2., 5., 4., 3., 1.,
                               3., 4., 3., 2., 1.,
                               4., 3., 2., 1., 0.]
    return res

def mat_dense2():
  return np.array([8.2, 1.8, 0.9, 2.6, 6.7, 7.6, 8.3,
                   8.7, 9.4, 2.6, 6.4, 3.5, 1.2, 4.7,
                   5.3, 9. , 8.7, 9.8, 4.6, 2.5, 4.6,
                   4.7, 6.2, 3.7, 5.6, 4.7, 8.3, 3. ,
                   3.5, 6.4, 2.3, 7.3, 4.2, 3.3, 8.9,
                   3.6, 6.2, 7.3, 3.1, 1.5, 4.1, 0.8,
                   8.8, 8.7, 1.6, 6.1, 5.6, 0.1, 8.5,
                   4.8, 4.1, 8.1, 0. , 0.4, 3. , 5.1,
                   6.6, 3.4, 1.7, 3.9, 2.2, 5.5, 6.8,
                   4.8, 3.7, 9.2, 7.4, 3.5, 1.5, 5.8,
                   4.3, 6.9, 6.5, 5.7, 7.6, 9.5, 5.8,
                   5.7, 6.9, 8.5, 0.1, 5.8, 9.6, 4.9,
                   6.9, 5.4, 0. , 1.2, 4.8, 1.5, 7.9,
                   2.8, 5.1, 0.6, 3. , 8.4, 8.6, 1. ,
                   8.1, 1.9, 6.3, 0.2, 0.3, 5.9, 0.]).reshape((15, 7))
