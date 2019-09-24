import hashlib


MNT4r_small = 475922286169261325753349249653048451545124878552823515553267735739164647307408490559963137
MNT4r_medium = 41898490967918953402344214791240637128170709919953949071783502921025352812571106773058893763790338921418070971888458477323173057491593855069696241854796396165721416325350064441470418137846398469611935719059908164220784476160001

def random_value(F, prefix, i):
    return F(int(hashlib.sha256('%s%d' % (prefix, i)).hexdigest(), 16))

m = 3
rounds = 50

prefix = 'CodaRescue'

def round_constants(F):
    name = prefix + 'RoundConstants'
    return [ [ random_value(F, name, r * m + i) for i in xrange(m) ]
            for r in xrange( rounds ) ]

def matrix_str(rows):
    return '[|' + ';'.join('[|' + ';'.join('Field.of_string "{}"'.format(str(x)) for x in row) + '|]' for row in rows) + '|]'

def mds(F):
    name = prefix + 'MDS'
    for attempt in xrange(100):
        x_values = [random_value(F, name + 'x', attempt * m + i)
                    for i in xrange(m)]
        y_values = [random_value(F, name + 'y', attempt * m + i)
                    for i in xrange(m)]
# Make sure the values are distinct.
        assert len(set(x_values + y_values)) == 2 * m, \
            'The values of x_values and y_values are not distinct'
        mds = matrix([[1 / (x_values[i] - y_values[j]) for j in xrange(m)]
                        for i in xrange(m)])
# Sanity check: check the determinant of the matrix.
        x_prod = product(
            [x_values[i] - x_values[j] for i in xrange(m) for j in xrange(i)])
        y_prod = product(
            [y_values[i] - y_values[j] for i in xrange(m) for j in xrange(i)])
        xy_prod = product(
            [x_values[i] - y_values[j] for i in xrange(m) for j in xrange(m)])
        expected_det = (1 if m % 4 < 2 else -1) * x_prod * y_prod / xy_prod
        det = mds.determinant()
        assert det != 0
        assert det == expected_det, \
            'Expected determinant %s. Found %s' % (expected_det, det)
        if len(mds.characteristic_polynomial().roots()) == 0:
            # There are no eigenvalues in the field.
            return mds

F_small= FiniteField(MNT4r_small)
F_medium = FiniteField(MNT4r_medium)

print ('''[%%import
"../../config.mlh"]''')
print ('''
open Curve_choice.Tick0

[%%if
curve_size = 298]''')
print ('let inv_alpha = "432656623790237568866681136048225865041022616866203195957516123399240588461280445963602851"')
print ('let mds =')
print (matrix_str(mds(F_small)))
print ('let round_constants =')
print (matrix_str(round_constants(F_small)))
print ('''
[%%elif
curve_size = 753]''')
print ('let inv_alpha = "38089537243562684911222013446582397389246099927230862792530457200932138920519187975508085239809399019470973610807689524839248234083267140972451128958905814696110378477590967674064016488951271336010850653690825603837076796509091"')
print ('let mds =')
print (matrix_str(mds(F_medium)))
print ('let round_constants =')
print (matrix_str(round_constants(F_medium)))
print ('''
[%%else]

[%%show
curve_size]

[%%error
"invalid value for \\"curve_size\\""]

[%%endif]''')
