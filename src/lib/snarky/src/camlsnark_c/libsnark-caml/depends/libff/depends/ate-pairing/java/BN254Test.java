import java.io.*;
import mcl.bn254.*;

public class BN254Test {
	static {
		System.loadLibrary("bn254_if_wrap");
	}
	public static void main(String argv[]) {
		try {
			BN254.SystemInit();

			Fp aa = new Fp("12723517038133731887338407189719511622662176727675373276651903807414909099441");
			Fp ab = new Fp("4168783608814932154536427934509895782246573715297911553964171371032945126671");
			Fp ba = new Fp("13891744915211034074451795021214165905772212241412891944830863846330766296736");
			Fp bb = new Fp("7937318970632701341203597196594272556916396164729705624521405069090520231616");
			Ec1 g1 = new Ec1(new Fp(-1), new Fp(1));
			Ec2 g2 = new Ec2(new Fp2(aa, ab), new Fp2(ba, bb));
			System.out.println("g1=" + g1);
			System.out.println("g2=" + g2);
			assertBool("g1 is on EC", g1.isValid());
			assertBool("g2 is on twist EC", g2.isValid());
			Mpz r = BN254.GetParamR();
			System.out.println("r=" + r);

			{
				Ec1 t = new Ec1(g1);
				t.mul(r);
				assertBool("orgder of g1 == r", t.isZero());
			}
			{
				Ec2 t = new Ec2(g2);
				t.mul(r);
				assertBool("order of g2 == r", t.isZero());
			}
			Mpz a = new Mpz("123456789012345");
			Mpz b = new Mpz("998752342342342342424242421");
			// scalar-multiplication sample
			{
				Mpz c = new Mpz(a);
				c.add(b);
				Ec1 Pa = new Ec1(g1); Pa.mul(a);
				Ec1 Pb = new Ec1(g1); Pb.mul(b);
				Ec1 Pc = new Ec1(g1); Pc.mul(c);
				Ec1 out = new Ec1(Pa);
				out.add(Pb);
				assertEqual("check g1 * c = g1 * a + g1 * b", Pc, out);
			}
			Fp12 e = new Fp12();
			// calc e : G2 x G1 -> G3 pairing
			e.pairing(g2, g1); // e = e(g2, g1)
			System.out.println("e=" + e);
			{
				Fp12 t = new Fp12(e);
				t.power(r);
				assertEqual("order of e == r", t, new Fp12(1));
			}
			Ec2 g2a = new Ec2(g2);
			g2a.mul(a);
			Fp12 ea1 = new Fp12();
			ea1.pairing(g2a, g1);
			Fp12 ea2 = new Fp12(e);
			ea2.power(a); // ea2 = e^a
			assertEqual("e(g2 * a, g1) = e(g2, g1)^a", ea1, ea2);

			Ec1 q1 = new Ec1(g1);
			q1.mul(new Mpz(12345));
			assertBool("q1 is on EC", q1.isValid());
			Fp12 e1 = new Fp12();
			Fp12 e2 = new Fp12();
			e1.pairing(g2, g1); // e1 = e(g2, g1)
			e2.pairing(g2, q1); // e2 = e(g2, q1)
			Ec1 q2 = new Ec1(g1);
			q2.add(q1);
			e.pairing(g2, q2); // e = e(g2, q2)
			e1.mul(e2);
			assertEqual("e = e1 * e2", e, e1);
		} catch (RuntimeException e) {
			System.out.println("unknown exception :" + e);
		}
	}
	public static void assertBool(String msg, Boolean b) {
		if (b) {
			System.out.println("OK : " + msg);
		} else {
			System.out.println("NG : " + msg);
		}
	}
	public static void assertEqual(String msg, Object lhs, Object rhs) {
		if (lhs.equals(rhs)) {
			System.out.println("OK : " + msg);
		} else {
			System.out.println("NG : " + msg + ", lhs = " + lhs + ", rhs = " + rhs);
		}
	}
}
