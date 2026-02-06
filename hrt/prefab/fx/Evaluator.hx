package hrt.prefab.fx;

class Evaluator {
	var randValues : Array<Float>;
	public var parameters: Map<String, Float> = [];
	var stride : Int;

	public function new(?randValues: Array<Float>, stride: Int=0) {
		this.randValues = randValues;
		this.stride = stride;
	}


	public static inline function vVal(v: Float) : Value {
		return VConst(v);
	}

	public static function optimize(val: Value) : Value {
		function opt(v: Value) : Value {
			function tryBoth(a: Value, b: Value, fn: (Value, Value) -> Null<Value>) : Null<Value> {
				var r = fn(a, b);
				return r != null ? r : fn(b, a);
			}
			return switch(v) {
				case VConst(c): c == 0.0 ? VZero : c == 1.0 ? VOne : v;
				case VCurveScale(c, s): s == 0.0 ? VZero : s == 1.0 ? VCurve(c) : v;
				case VRandomScale(_, s): s == 0.0 ? VZero : v;
				case VAddRandomScale(_, s, add): s == 0.0 ? opt(VConst(add)) : v;
				case VAddRandCurve(cst, _, rs, c): rs == 0.0 ? (cst == 0.0 ? VZero : cst == 1.0 ? VCurve(c) : VCurveScale(c, cst)) : v;
				case VMult(a, b):
					var a = opt(a), b = opt(b);
					var r = tryBoth(a, b, (x, y) -> switch(x) {
						case VZero: VZero;
						case VOne: y;
						case VConst(va): switch(y) {
							case VConst(vb): VConst(va * vb);
							case VCurve(c): VCurveScale(c, va);
							case VCurveScale(c, s): VCurveScale(c, s * va);
							case VRandomScale(ri, rs): VRandomScale(ri, rs * va);
							case VAddRandomScale(ri, rs, add): VAddRandomScale(ri, rs * va, add * va);
							default: null;
						}
						case VRandomScale(ri, rs): switch(y) {
							case VCurve(c): VAddRandCurve(0, ri, rs, c);
							default: null;
						}
						case VAddRandomScale(ri, rs, add): switch(y) {
							case VCurve(c): VAddRandCurve(add, ri, rs, c);
							default: null;
						}
						default: null;
					});
					r != null ? opt(r) : VMult(a, b);
				case VAdd(a, b):
					var a = opt(a), b = opt(b);
					var r = tryBoth(a, b, (x, y) -> switch(x) {
						case VZero: y;
						case VOne: switch(y) {
							case VConst(vb): VConst(1.0 + vb);
							case VRandomScale(ri, rs): VAddRandomScale(ri, rs, 1.0);
							case VAddRandomScale(ri, rs, add): VAddRandomScale(ri, rs, 1.0 + add);
							default: null;
						}
						case VConst(va): switch(y) {
							case VConst(vb): VConst(va + vb);
							case VRandomScale(ri, rs): VAddRandomScale(ri, rs, va);
							case VAddRandomScale(ri, rs, add): VAddRandomScale(ri, rs, va + add);
							default: null;
						}
						default: null;
					});
					r != null ? opt(r) : VAdd(a, b);
				case VVector(x, y, z, w): VVector(opt(x), opt(y), opt(z), w != null ? opt(w) : null);
				case VHsl(h, s, l, a): VHsl(opt(h), opt(s), opt(l), opt(a));
				case VBlend(a, b, p): VBlend(opt(a), opt(b), p);
				case VParamRemap(a, p): VParamRemap(opt(a), p);
				case VValueRemap(a, r): VValueRemap(opt(a), opt(r));
				case VRandom(ri, s): VRandom(ri, opt(s));
				case VBool(a): VBool(opt(a));
				case VInt(a): VInt(opt(a));
				default: v;
			}
		}
		return opt(val);
	}

	inline function getRandom(pidx: Int, ridx: Int) {
		var i = pidx * stride + ridx;
		return randValues[i];
	}

	public function setAllParameters(params: Array<hrt.prefab.fx.FX.Parameter>) {
		parameters.clear();
		if (params == null)
			return;
		for (p in params) {
			parameters[p.name] = p.def;
		}
	}

	function getFloatSlow(pidx: Int=0, val: Value, time: Float) : Float {
		return switch(val) {
			case VCurve(c):  c.getVal(time);
			case VCurveScale(c, scale): c.getVal(time) * scale;
			case VAddRandCurve(cst, ridx, rscale, c): (cst + getRandom(pidx, ridx) * rscale) * c.getVal(time);
			case VBlend(a,b,v):
				var blend = parameters[v] ?? 0.0;
				return hxd.Math.lerp(getFloatSlow(pidx, a, time), getFloatSlow(pidx, b, time), blend);
			case VParamRemap(a, param):
				var time = parameters[param] ?? 0.0;
				return getFloatSlow(pidx, a, time);
			case VValueRemap(a, remap):
				var time = getFloatSlow(pidx, remap, time);
				return getFloatSlow(pidx, a, time);
			case VRandomBetweenCurves(ridx, c):
				{
					var c1 = Std.downcast(c.children[0], Curve);
					var c2 = Std.downcast(c.children[1], Curve);
					var a = c1.getVal(time);
					var b = c2.getVal(time);

					// Should be in [0,1]
					var rand = getRandom(pidx, ridx);
					var min = -1;
					var max = 1;
					var remappedRand = (rand - min) / (max - min);
					return a + (b - a) * remappedRand;
				}
			case VRandom(ridx, scale):
				return getRandom(pidx, ridx) * getFloatSlow(pidx, scale, time);
			case VMult(a, b):
				return getFloatSlow(pidx, a, time) * getFloatSlow(pidx, b, time);
			case VAdd(a, b):
				return getFloatSlow(pidx, a, time) + getFloatSlow(pidx, b, time);
			default:
				return getFloat(pidx, val, time);
		}
	}

	inline public function getFloat(pidx: Int=0, val: Value, time: Float) : Float {
		return switch(val) {
			case VZero: return 0.0;
			case VOne: return 1.0;
			case VConst(v): v;
			case VRandomScale(ridx, scale): getRandom(pidx, ridx) * scale;
			case VAddRandomScale(ridx, scale, add): getRandom(pidx, ridx) * scale + add;
			default:
				getFloatSlow(pidx, val, time);
		}
	}

	public function getSum(val: Value, time: Float) : Float {
		switch(val) {
			case VOne: return time;
			case VConst(v): return v * time;
			case VCurve(c): return c.getSum(time);
			case VAdd(a, b):
				return getSum(a, time) + getSum(b, time);
			case VParamRemap(a, param):
				var blend = parameters[param] ?? 0.0;
				return getSum(a, blend) * time;
			case VMult(a, VConst(b)), VMult(VConst(b), a): return getSum(a, time) * b;
			case VZero: return 0;
			case VBlend(a,b,v):
				var blend = parameters[v] ?? 0.0;
				return hxd.Math.lerp(getSum(a, time), getSum(b, time), blend);
			default: throw "not implemented";
		}
		return 0.0;
	}

	public function getVector(pidx: Int=0, v: Value, time: Float, vec: h3d.Vector4) {
		switch(v) {
			case VVector(x, y, z, null):
				vec.set(getFloat(pidx, x, time), getFloat(pidx, y, time), getFloat(pidx, z, time), 1.0);
			case VVector(x, y, z, w):
				vec.set(getFloat(pidx, x, time), getFloat(pidx, y, time), getFloat(pidx, z, time), getFloat(pidx, w, time));
			case VHsl(h, s, l, a):
				var hval = getFloat(pidx, h, time);
				var sval = getFloat(pidx, s, time);
				var lval = getFloat(pidx, l, time);
				var aval = getFloat(pidx, a, time);
				vec.makeColor(hval, sval, lval);
				vec.a = aval;
			case VZero:
				vec.set(0,0,0,1);
			case VOne:
				vec.set(1,1,1,1);
			default:
				var f = getFloat(pidx, v, time);
				vec.set(f, f, f, 1.0);
		}
		return vec;
	}

	public function getVector2(pidx: Int=0, v: Value, time: Float, vec: h2d.col.Point) {
		switch(v) {
			case VMult(a, b):
				throw "need optimization";
			case VVector(x, y, z, null):
				vec.set(getFloat(pidx, x, time), getFloat(pidx, y, time));
			case VVector(x, y, z, w):
				vec.set(getFloat(pidx, x, time), getFloat(pidx, y, time));
			case VZero:
				vec.set(0,0);
			case VOne:
				vec.set(1,1);
			default:
				var f = getFloat(pidx, v, time);
				vec.set(f, f);
		}
		return vec;
	}
}