class_name KeyedDraw
extends RefCounted


## Four 16-bit limbs avoid signed overflow and arithmetic right shifts.
static func limbs(value: String) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0]
	for digit: String in value:
		var carry := int(digit)
		for i: int in 4:
			var n := out[i] * 10 + carry
			out[i] = n & 65535
			carry = n >> 16
	return out


static func mul(a: Array[int], b: Array[int]) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0]
	var carry: int = 0
	for k: int in 4:
		var n := carry
		for i: int in k + 1:
			n += a[i] * b[k - i]
		out[k] = n & 65535
		carry = n >> 16
	return out


static func xor_shift(a: Array[int], shift: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in 4:
		var bit := i * 16 + shift
		var shifted: int = 0
		if bit < 64:
			shifted = a[bit / 16] >> (bit % 16)
			if bit / 16 + 1 < 4 and bit % 16 != 0:
				shifted |= a[bit / 16 + 1] << (16 - bit % 16)
		out.append(a[i] ^ (shifted & 65535))
	return out


static func draw(seed: String, tick: String, event: String, purpose: String = "0") -> String:
	var a := limbs(seed)
	var b := mul(limbs(tick), limbs("11400714819323198485"))
	var c := mul(limbs(event), limbs("15111065706836454659"))
	var d := mul(limbs(purpose), limbs("10723151780598845931"))
	for i: int in 4:
		a[i] = a[i] ^ b[i] ^ c[i] ^ d[i]
	a = mul(xor_shift(a, 30), limbs("13787848793156543929"))
	a = mul(xor_shift(a, 27), limbs("10723151780598845931"))
	a = xor_shift(a, 31)
	var out := ""
	while a != [0, 0, 0, 0]:
		var remainder: int = 0
		for i: int in range(3, -1, -1):
			var n := remainder * 65536 + a[i]
			a[i] = n / 10
			remainder = n % 10
		out = str(remainder) + out
	return "0" if out.is_empty() else out
