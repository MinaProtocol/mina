use blake2b_simd::{Hash as Blake2bHash, Params as Blake2bParams, State as Blake2bState};
use byteorder::{BigEndian, LittleEndian, ReadBytesExt, WriteBytesExt};
use log::error;
use std::io::Cursor;
use std::mem::size_of;

struct Params {
    n: u32,
    k: u32,
}

#[derive(Clone)]
struct Node {
    hash: Vec<u8>,
    indices: Vec<u32>,
}

impl Params {
    fn indices_per_hash_output(&self) -> u32 {
        512 / self.n
    }
    fn hash_output(&self) -> u8 {
        (self.indices_per_hash_output() * self.n / 8) as u8
    }
    fn collision_bit_length(&self) -> usize {
        (self.n / (self.k + 1)) as usize
    }
    fn collision_byte_length(&self) -> usize {
        (self.collision_bit_length() + 7) / 8
    }
    fn hash_length(&self) -> usize {
        ((self.k as usize) + 1) * self.collision_byte_length()
    }
}

impl Node {
    fn new(p: &Params, state: &Blake2bState, i: u32) -> Self {
        let hash = generate_hash(state, i / p.indices_per_hash_output());
        let start = ((i % p.indices_per_hash_output()) * p.n / 8) as usize;
        let end = start + (p.n as usize) / 8;
        Node {
            hash: expand_array(&hash.as_bytes()[start..end], p.collision_bit_length(), 0),
            indices: vec![i],
        }
    }

    fn from_children(a: Node, b: Node, trim: usize) -> Self {
        let hash: Vec<_> = a
            .hash
            .iter()
            .zip(b.hash.iter())
            .skip(trim)
            .map(|(a, b)| a ^ b)
            .collect();
        let indices = if a.indices_before(&b) {
            let mut indices = a.indices;
            indices.extend(b.indices.iter());
            indices
        } else {
            let mut indices = b.indices;
            indices.extend(a.indices.iter());
            indices
        };
        Node { hash, indices }
    }

    fn from_children_ref(a: &Node, b: &Node, trim: usize) -> Self {
        let hash: Vec<_> = a
            .hash
            .iter()
            .zip(b.hash.iter())
            .skip(trim)
            .map(|(a, b)| a ^ b)
            .collect();
        let mut indices = Vec::with_capacity(a.indices.len() + b.indices.len());
        if a.indices_before(b) {
            indices.extend(a.indices.iter());
            indices.extend(b.indices.iter());
        } else {
            indices.extend(b.indices.iter());
            indices.extend(a.indices.iter());
        }
        Node { hash, indices }
    }

    fn indices_before(&self, other: &Node) -> bool {
        // Indices are serialized in big-endian so that integer
        // comparison is equivalent to array comparison
        self.indices[0] < other.indices[0]
    }

    fn is_zero(&self, len: usize) -> bool {
        self.hash.iter().take(len).all(|v| *v == 0)
    }
}

fn initialise_state(n: u32, k: u32, digest_len: u8) -> Blake2bState {
    let mut personalization: Vec<u8> = Vec::from("ZcashPoW");
    personalization.write_u32::<LittleEndian>(n).unwrap();
    personalization.write_u32::<LittleEndian>(k).unwrap();

    Blake2bParams::new()
        .hash_length(digest_len as usize)
        .personal(&personalization)
        .to_state()
}

fn generate_hash(base_state: &Blake2bState, i: u32) -> Blake2bHash {
    let mut lei = [0u8; 4];
    (&mut lei[..]).write_u32::<LittleEndian>(i).unwrap();

    let mut state = base_state.clone();
    state.update(&lei);
    state.finalize()
}

fn expand_array(vin: &[u8], bit_len: usize, byte_pad: usize) -> Vec<u8> {
    assert!(bit_len >= 8);
    assert!(8 * size_of::<u32>() >= 7 + bit_len);

    let out_width = (bit_len + 7) / 8 + byte_pad;
    let out_len = 8 * out_width * vin.len() / bit_len;

    // Shortcut for parameters where expansion is a no-op
    if out_len == vin.len() {
        return vin.to_vec();
    }

    let mut vout: Vec<u8> = vec![0; out_len];
    let bit_len_mask: u32 = (1 << bit_len) - 1;

    // The acc_bits least-significant bits of acc_value represent a bit sequence
    // in big-endian order.
    let mut acc_bits = 0;
    let mut acc_value: u32 = 0;

    let mut j = 0;
    for b in vin {
        acc_value = (acc_value << 8) | u32::from(*b);
        acc_bits += 8;

        // When we have bit_len or more bits in the accumulator, write the next
        // output element.
        if acc_bits >= bit_len {
            acc_bits -= bit_len;
            for x in byte_pad..out_width {
                vout[j + x] = ((
                    // Big-endian
                    acc_value >> (acc_bits + (8 * (out_width - x - 1)))
                ) & (
                    // Apply bit_len_mask across byte boundaries
                    (bit_len_mask >> (8 * (out_width - x - 1))) & 0xFF
                )) as u8;
            }
            j += out_width;
        }
    }

    vout
}

fn indices_from_minimal(minimal: &[u8], c_bit_len: usize) -> Vec<u32> {
    assert!(((c_bit_len + 1) + 7) / 8 <= size_of::<u32>());
    let len_indices = 8 * size_of::<u32>() * minimal.len() / (c_bit_len + 1);
    let byte_pad = size_of::<u32>() - ((c_bit_len + 1) + 7) / 8;

    let mut csr = Cursor::new(expand_array(minimal, c_bit_len + 1, byte_pad));
    let mut ret = Vec::with_capacity(len_indices);

    // Big-endian so that lexicographic array comparison is equivalent to integer
    // comparison
    while let Ok(i) = csr.read_u32::<BigEndian>() {
        ret.push(i);
    }

    ret
}

fn has_collision(a: &Node, b: &Node, len: usize) -> bool {
    a.hash
        .iter()
        .zip(b.hash.iter())
        .take(len)
        .all(|(a, b)| a == b)
}

fn distinct_indices(a: &Node, b: &Node) -> bool {
    for i in &(a.indices) {
        for j in &(b.indices) {
            if i == j {
                return false;
            }
        }
    }
    true
}

fn validate_subtrees(p: &Params, a: &Node, b: &Node) -> bool {
    if !has_collision(a, b, p.collision_byte_length()) {
        error!("Invalid solution: invalid collision length between StepRows");
        false
    } else if b.indices_before(a) {
        error!("Invalid solution: Index tree incorrectly ordered");
        false
    } else if !distinct_indices(a, b) {
        error!("Invalid solution: duplicate indices");
        false
    } else {
        true
    }
}

pub fn is_valid_solution_iterative(
    n: u32,
    k: u32,
    input: &[u8],
    nonce: &[u8],
    indices: &[u32],
) -> bool {
    let p = Params { n, k };

    let mut state = initialise_state(p.n, p.k, p.hash_output());
    state.update(input);
    state.update(nonce);

    let mut rows = Vec::new();
    for i in indices {
        rows.push(Node::new(&p, &state, *i));
    }

    let mut hash_len = p.hash_length();
    while rows.len() > 1 {
        let mut cur_rows = Vec::new();
        for pair in rows.chunks(2) {
            let a = &pair[0];
            let b = &pair[1];
            if !validate_subtrees(&p, a, b) {
                return false;
            }
            cur_rows.push(Node::from_children_ref(a, b, p.collision_byte_length()));
        }
        rows = cur_rows;
        hash_len -= p.collision_byte_length();
    }

    assert!(rows.len() == 1);
    rows[0].is_zero(hash_len)
}

fn tree_validator(p: &Params, state: &Blake2bState, indices: &[u32]) -> Option<Node> {
    if indices.len() > 1 {
        let end = indices.len();
        let mid = end / 2;
        match tree_validator(p, state, &indices[0..mid]) {
            Some(a) => match tree_validator(p, state, &indices[mid..end]) {
                Some(b) => {
                    if validate_subtrees(p, &a, &b) {
                        Some(Node::from_children(a, b, p.collision_byte_length()))
                    } else {
                        None
                    }
                }
                None => None,
            },
            None => None,
        }
    } else {
        Some(Node::new(&p, &state, indices[0]))
    }
}

pub fn is_valid_solution_recursive(
    n: u32,
    k: u32,
    input: &[u8],
    nonce: &[u8],
    indices: &[u32],
) -> bool {
    let p = Params { n, k };

    let mut state = initialise_state(p.n, p.k, p.hash_output());
    state.update(input);
    state.update(nonce);

    match tree_validator(&p, &state, indices) {
        Some(root) => {
            // Hashes were trimmed, so only need to check remaining length
            root.is_zero(p.collision_byte_length())
        }
        None => false,
    }
}

pub fn is_valid_solution(n: u32, k: u32, input: &[u8], nonce: &[u8], soln: &[u8]) -> bool {
    let p = Params { n, k };
    let indices = indices_from_minimal(soln, p.collision_bit_length());

    // Recursive validation is faster
    is_valid_solution_recursive(n, k, input, nonce, &indices)
}

#[cfg(test)]
mod tests {
    use super::is_valid_solution_iterative;
    use super::is_valid_solution_recursive;

    fn is_valid_solution(n: u32, k: u32, input: &[u8], nonce: &[u8], indices: &[u32]) -> bool {
        let a = is_valid_solution_iterative(n, k, input, nonce, indices);
        let b = is_valid_solution_recursive(n, k, input, nonce, indices);
        assert!(a == b);
        a
    }

    #[test]
    fn equihash_test_cases() {
        let input = b"block header";
        let mut nonce = [0 as u8; 32];
        let mut indices = vec![
            976, 126621, 100174, 123328, 38477, 105390, 38834, 90500, 6411, 116489, 51107, 129167,
            25557, 92292, 38525, 56514, 1110, 98024, 15426, 74455, 3185, 84007, 24328, 36473,
            17427, 129451, 27556, 119967, 31704, 62448, 110460, 117894,
        ];
        assert!(is_valid_solution(96, 5, input, &nonce, &indices));

        indices = vec![
            1008, 18280, 34711, 57439, 3903, 104059, 81195, 95931, 58336, 118687, 67931, 123026,
            64235, 95595, 84355, 122946, 8131, 88988, 45130, 58986, 59899, 78278, 94769, 118158,
            25569, 106598, 44224, 96285, 54009, 67246, 85039, 127667,
        ];
        assert!(is_valid_solution(96, 5, input, &nonce, &indices));

        indices = vec![
            4313, 223176, 448870, 1692641, 214911, 551567, 1696002, 1768726, 500589, 938660,
            724628, 1319625, 632093, 1474613, 665376, 1222606, 244013, 528281, 1741992, 1779660,
            313314, 996273, 435612, 1270863, 337273, 1385279, 1031587, 1147423, 349396, 734528,
            902268, 1678799, 10902, 1231236, 1454381, 1873452, 120530, 2034017, 948243, 1160178,
            198008, 1704079, 1087419, 1734550, 457535, 698704, 649903, 1029510, 75564, 1860165,
            1057819, 1609847, 449808, 527480, 1106201, 1252890, 207200, 390061, 1557573, 1711408,
            396772, 1026145, 652307, 1712346, 10680, 1027631, 232412, 974380, 457702, 1827006,
            1316524, 1400456, 91745, 2032682, 192412, 710106, 556298, 1963798, 1329079, 1504143,
            102455, 974420, 639216, 1647860, 223846, 529637, 425255, 680712, 154734, 541808,
            443572, 798134, 322981, 1728849, 1306504, 1696726, 57884, 913814, 607595, 1882692,
            236616, 1439683, 420968, 943170, 1014827, 1446980, 1468636, 1559477, 1203395, 1760681,
            1439278, 1628494, 195166, 198686, 349906, 1208465, 917335, 1361918, 937682, 1885495,
            494922, 1745948, 1320024, 1826734, 847745, 894084, 1484918, 1523367, 7981, 1450024,
            861459, 1250305, 226676, 329669, 339783, 1935047, 369590, 1564617, 939034, 1908111,
            1147449, 1315880, 1276715, 1428599, 168956, 1442649, 766023, 1171907, 273361, 1902110,
            1169410, 1786006, 413021, 1465354, 707998, 1134076, 977854, 1604295, 1369720, 1486036,
            330340, 1587177, 502224, 1313997, 400402, 1667228, 889478, 946451, 470672, 2019542,
            1023489, 2067426, 658974, 876859, 794443, 1667524, 440815, 1099076, 897391, 1214133,
            953386, 1932936, 1100512, 1362504, 874364, 975669, 1277680, 1412800, 1227580, 1857265,
            1312477, 1514298, 12478, 219890, 534265, 1351062, 65060, 651682, 627900, 1331192,
            123915, 865936, 1218072, 1732445, 429968, 1097946, 947293, 1323447, 157573, 1212459,
            923792, 1943189, 488881, 1697044, 915443, 2095861, 333566, 732311, 336101, 1600549,
            575434, 1978648, 1071114, 1473446, 50017, 54713, 367891, 2055483, 561571, 1714951,
            715652, 1347279, 584549, 1642138, 1002587, 1125289, 1364767, 1382627, 1387373, 2054399,
            97237, 1677265, 707752, 1265819, 121088, 1810711, 1755448, 1858538, 444653, 1130822,
            514258, 1669752, 578843, 729315, 1164894, 1691366, 15609, 1917824, 173620, 587765,
            122779, 2024998, 804857, 1619761, 110829, 1514369, 410197, 493788, 637666, 1765683,
            782619, 1186388, 494761, 1536166, 1582152, 1868968, 825150, 1709404, 1273757, 1657222,
            817285, 1955796, 1014018, 1961262, 873632, 1689675, 985486, 1008905, 130394, 897076,
            419669, 535509, 980696, 1557389, 1244581, 1738170, 197814, 1879515, 297204, 1165124,
            883018, 1677146, 1545438, 2017790, 345577, 1821269, 761785, 1014134, 746829, 751041,
            930466, 1627114, 507500, 588000, 1216514, 1501422, 991142, 1378804, 1797181, 1976685,
            60742, 780804, 383613, 645316, 770302, 952908, 1105447, 1878268, 504292, 1961414,
            693833, 1198221, 906863, 1733938, 1315563, 2049718, 230826, 2064804, 1224594, 1434135,
            897097, 1961763, 993758, 1733428, 306643, 1402222, 532661, 627295, 453009, 973231,
            1746809, 1857154, 263652, 1683026, 1082106, 1840879, 768542, 1056514, 888164, 1529401,
            327387, 1708909, 961310, 1453127, 375204, 878797, 1311831, 1969930, 451358, 1229838,
            583937, 1537472, 467427, 1305086, 812115, 1065593, 532687, 1656280, 954202, 1318066,
            1164182, 1963300, 1232462, 1722064, 17572, 923473, 1715089, 2079204, 761569, 1557392,
            1133336, 1183431, 175157, 1560762, 418801, 927810, 734183, 825783, 1844176, 1951050,
            317246, 336419, 711727, 1630506, 634967, 1595955, 683333, 1461390, 458765, 1834140,
            1114189, 1761250, 459168, 1897513, 1403594, 1478683, 29456, 1420249, 877950, 1371156,
            767300, 1848863, 1607180, 1819984, 96859, 1601334, 171532, 2068307, 980009, 2083421,
            1329455, 2030243, 69434, 1965626, 804515, 1339113, 396271, 1252075, 619032, 2080090,
            84140, 658024, 507836, 772757, 154310, 1580686, 706815, 1024831, 66704, 614858, 256342,
            957013, 1488503, 1615769, 1515550, 1888497, 245610, 1333432, 302279, 776959, 263110,
            1523487, 623933, 2013452, 68977, 122033, 680726, 1849411, 426308, 1292824, 460128,
            1613657, 234271, 971899, 1320730, 1559313, 1312540, 1837403, 1690310, 2040071, 149918,
            380012, 785058, 1675320, 267071, 1095925, 1149690, 1318422, 361557, 1376579, 1587551,
            1715060, 1224593, 1581980, 1354420, 1850496, 151947, 748306, 1987121, 2070676, 273794,
            981619, 683206, 1485056, 766481, 2047708, 930443, 2040726, 1136227, 1945705, 1722044,
            1971986,
        ];
        assert!(!is_valid_solution(96, 5, input, &nonce, &indices));
        assert!(is_valid_solution(200, 9, input, &nonce, &indices));

        nonce[0] = 1;
        assert!(!is_valid_solution(96, 5, input, &nonce, &indices));
        assert!(!is_valid_solution(200, 9, input, &nonce, &indices));

        indices = vec![
            1911, 96020, 94086, 96830, 7895, 51522, 56142, 62444, 15441, 100732, 48983, 64776,
            27781, 85932, 101138, 114362, 4497, 14199, 36249, 41817, 23995, 93888, 35798, 96337,
            5530, 82377, 66438, 85247, 39332, 78978, 83015, 123505,
        ];
        assert!(is_valid_solution(96, 5, input, &nonce, &indices));

        indices = vec![
            1505, 1380774, 200806, 1787044, 101056, 1697952, 281464, 374899, 263712, 1532496,
            264180, 637056, 734225, 1882676, 1112004, 2093109, 193394, 1459136, 525171, 657480,
            214528, 1221365, 574444, 594726, 501919, 1309358, 1740268, 1989610, 654491, 1068055,
            919416, 1993208, 17599, 1858176, 1315176, 1901532, 108258, 109600, 1117445, 1936058,
            70247, 1036984, 628234, 1800109, 149791, 365740, 345683, 563554, 21678, 822781,
            1423722, 1644228, 792912, 1409641, 805060, 2041985, 453824, 1003179, 934427, 1068834,
            629003, 1456111, 670049, 1558594, 19016, 1343657, 1698188, 1865216, 45723, 1820952,
            1160970, 1585983, 422549, 1973097, 1296271, 2006382, 650084, 809838, 871727, 1080419,
            28500, 1471829, 384406, 619459, 212041, 1466258, 481435, 866461, 145340, 1403843,
            1339592, 1405761, 163425, 1073771, 285027, 1488210, 167744, 1182267, 1354059, 2089602,
            921700, 2059931, 1704721, 1853088, 585171, 739246, 747551, 1520527, 590255, 1175747,
            705292, 998433, 522014, 1931179, 1629531, 1692879, 588830, 1799457, 963672, 1664237,
            775408, 1926741, 907030, 1466738, 784179, 1972599, 1494787, 1598114, 1736, 1039487,
            88704, 1302687, 579526, 1476728, 1677992, 1854526, 432470, 2062305, 1471132, 1747579,
            1521894, 1917599, 1590975, 1936227, 151871, 1999775, 224664, 461809, 704084, 1306665,
            1316156, 1529628, 876811, 2086004, 1986383, 2012147, 1039505, 1637502, 1432721,
            1565477, 110385, 342650, 659137, 1285167, 367416, 2007586, 445677, 2084877, 285692,
            1144365, 988840, 1990372, 748425, 1617758, 1267712, 1510433, 152291, 1256291, 1722179,
            1995439, 864844, 1623380, 1071853, 1731862, 699978, 1407662, 1048047, 1849702, 962900,
            1083340, 1378752, 1534902, 11843, 115329, 454796, 548919, 148184, 1686936, 862432,
            873854, 60753, 999864, 385959, 1528101, 534420, 678401, 590419, 1962518, 54984,
            1141820, 243305, 1349970, 599681, 1817233, 1632537, 1698724, 580004, 673073, 1403350,
            2026104, 758881, 970056, 1717966, 2062827, 19624, 148580, 609748, 1588928, 456321,
            834920, 700532, 1682606, 20012, 441139, 1591072, 1923394, 194034, 1741063, 1156906,
            1983067, 20703, 1939972, 604581, 963600, 128170, 731716, 606773, 1626824, 139460,
            1386775, 521911, 2043473, 392180, 449532, 895678, 1453340, 7085, 598416, 1514260,
            2061068, 279532, 678363, 943255, 1405306, 119114, 2075865, 592839, 1972064, 254647,
            2078288, 946282, 1567138, 120422, 767626, 213242, 448366, 438457, 1768467, 853790,
            1509505, 735780, 1979631, 1461410, 1462050, 739008, 1572606, 920754, 1507358, 12883,
            1681167, 1308399, 1839490, 85599, 1387522, 703262, 1949514, 18523, 1236125, 669105,
            1464132, 68670, 2085647, 333393, 1731573, 21714, 637827, 985912, 2091029, 84065,
            1688993, 1574405, 1899543, 134032, 179206, 671016, 1118310, 288960, 861994, 622074,
            1738892, 10936, 343910, 598016, 1741971, 586348, 1956071, 851053, 1715626, 531385,
            1213667, 1093995, 1863757, 630365, 1851894, 1328101, 1770446, 31900, 734027, 1078651,
            1701535, 123276, 1916343, 581822, 1681706, 573135, 818091, 1454710, 2052521, 1150284,
            1451159, 1482280, 1811430, 26321, 785837, 877980, 2073103, 107324, 727248, 1785460,
            1840517, 184560, 185640, 364103, 1878753, 518459, 1984029, 964109, 1884200, 74003,
            527272, 516232, 711247, 148582, 209254, 634610, 1534140, 376714, 1573267, 421225,
            1265101, 1078858, 1374310, 1806283, 2091298, 23392, 389637, 413663, 1066737, 226164,
            762552, 1048220, 1583397, 40092, 277435, 775449, 1533894, 202582, 390703, 346741,
            1027320, 523034, 809424, 584882, 1296934, 528062, 733331, 1212771, 1958651, 653372,
            1313962, 1366332, 1784489, 1542466, 1580386, 1628948, 2000957, 57069, 1398636, 1250431,
            1698486, 57289, 596009, 582428, 966130, 167657, 1025537, 1227498, 1630134, 234060,
            1285209, 265623, 1165779, 68485, 632055, 96019, 1854676, 98410, 158575, 168035,
            1296171, 158847, 1243959, 977212, 1113647, 363568, 891940, 954593, 1987111, 90101,
            133251, 1136222, 1255117, 543075, 732768, 749576, 1174878, 422226, 1854657, 1143029,
            1457135, 927105, 1137382, 1566306, 1661926, 103057, 425126, 698089, 1774942, 911019,
            1793511, 1623559, 2002409, 457796, 1196971, 724257, 1811147, 956269, 1165590, 1137531,
            1381215, 201063, 1938529, 986021, 1297857, 921334, 1259083, 1440074, 1939366, 232907,
            747213, 1349009, 1945364, 689906, 1116453, 1904207, 1916192, 229793, 1576982, 1420059,
            1644978, 278248, 2024807, 297914, 419798, 555747, 712605, 1012424, 1428921, 890113,
            1822645, 1082368, 1392894,
        ];
        assert!(!is_valid_solution(96, 5, input, &nonce, &indices));
        assert!(is_valid_solution(200, 9, input, &nonce, &indices));

        let input2 = b"Equihash is an asymmetric PoW based on the Generalised Birthday problem.";
        indices = vec![
            2261, 15185, 36112, 104243, 23779, 118390, 118332, 130041, 32642, 69878, 76925, 80080,
            45858, 116805, 92842, 111026, 15972, 115059, 85191, 90330, 68190, 122819, 81830, 91132,
            23460, 49807, 52426, 80391, 69567, 114474, 104973, 122568,
        ];
        assert!(is_valid_solution(96, 5, input2, &nonce, &indices));
    }
}
