package hrt.prefab.fx;

class Evaluator {
	var randValues : Array<Float>;
	public var parameters: Map<String, Float> = [];
	var stride : Int;

	public function new(?randValues: Array<Float>, stride: Int=0) {
		this.randValues = randValues;
		this.stride = stride;
	}


	public static function optimize(val: Value) : Value {
		function opt(v: Value) : Value {
			function tryBoth(a: Value, b: Value, fn: (Value, Value) -> Null<Value>) : Null<Value> {
				var r = fn(a, b);
				return r != null ? r : fn(b, a);
			}
			return switch(v) {
				case VConst(0.0): VZero;
				case VMult(a, b):
					var a = opt(a);
					var b = opt(b);
					var r = tryBoth(a, b, (x, y) -> switch(x) {
						case VZero: VZero;
						case VConst(va): switch(y) {
							case VConst(vb): VConst(va * vb);
							case VBlendCurves(a, b, v, s): VBlendCurves(a, b, v, s * va);
							default: null;
						}
						case VCurve(c): switch(y) {
							case VConst(vb): VOptCurve(c, vb, 0.0);
							case VRandom(ri, rs, add): VMultRandCurve(ri, rs, add, c);
							default: null;
						}
						default: null;
					});
					r != null ? r : VMult(a, b);
				case VAdd(a, b):
					var a = opt(a);
					var b = opt(b);
					var r = tryBoth(a, b, (x, y) -> switch(x) {
						case VZero: y;
						case VCurve(c): switch(y) {
							case VConst(vb): VOptCurve(c, 1.0, vb);
							case VRandom(ri, rs, add): VAddRandCurve(ri, rs, add, c);
							default: null;
						}
						case VConst(va): switch(y) {
							case VConst(vb): VConst(va + vb);
							case VRandom(ri, rs, ra): VRandom(ri, rs, ra + va);
							default: null;
						}
						default: null;
					});
					r != null ? r : VAdd(a, b);
				case VVector(x, y, z, w):
					var ox = opt(x);
					var oy = opt(y);
					var oz = opt(z);
					var ow = w != null ? opt(w) : null;
					if(ox == VZero && oy == VZero && oz == VZero && (ow == null || ow == VZero))
						VZero;
					else
						VVector(ox, oy, oz, ow);
				case VParamRemap(a, p): VParamRemap(opt(a), p);
				case VValueRemap(a, r): VValueRemap(opt(a), opt(r));
				//case VRandom(ri, s): VRandom(ri, opt(s));
				default: v;
			}
		}

		var r = opt(val);
		addStat(val, r);
		return r;
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
			case VOptCurve(c, scale, offset): c.getVal(time) * scale + offset;
			case VMultRandCurve(ridx, rscale, radd, c): (getRandom(pidx, ridx) * rscale + radd) * c.getVal(time);
			case VAddRandCurve(ridx, rscale, radd, c): (getRandom(pidx, ridx) * rscale + radd) + c.getVal(time);
			case VBlendCurves(a,b,v,s):
				var blend = parameters[v] ?? 0.0;
				return hxd.Math.lerp(a.getVal(time), b.getVal(time), blend) * s;
			case VParamRemap(a, param):
				var time = parameters[param] ?? 0.0;
				return getFloatSlow(pidx, a, time);
			case VValueRemap(a, remap):
				var time = getFloatSlow(pidx, remap, time);
				return getFloatSlow(pidx, a, time);
			case VRandomBetweenCurves(ridx, c1, c2):
				{
					var a = c1.getVal(time);
					var b = c2.getVal(time);

					// Should be in [0,1]
					var rand = getRandom(pidx, ridx);
					var min = -1;
					var max = 1;
					var remappedRand = (rand - min) / (max - min);
					return a + (b - a) * remappedRand;
				}
			// case VRandom(ridx, scale):
			// 	return getRandom(pidx, ridx) * getFloatSlow(pidx, scale, time);
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
			case VConst(v): v;
			// case VRandomScale(ridx, scale): getRandom(pidx, ridx) * scale;
			case VRandom(ridx, scale, add): getRandom(pidx, ridx) * scale + add;
			default:
				getFloatSlow(pidx, val, time);
		}
	}

	public function getSum(val: Value, time: Float) : Float {
		switch(val) {
			case VConst(v): return v * time;
			case VCurve(c): return c.getSum(time);
			case VOptCurve(c, scale, 0.0): return c.getSum(time) * scale;
			case VAdd(a, b):
				return getSum(a, time) + getSum(b, time);
			case VParamRemap(a, param):
				var blend = parameters[param] ?? 0.0;
				return getSum(a, blend) * time;
			case VMult(a, VConst(b)), VMult(VConst(b), a): return getSum(a, time) * b;
			case VZero: return 0;
			case VBlendCurves(a,b,v,s):
				var blend = parameters[v] ?? 0.0;
				return hxd.Math.lerp(a.getSum(time), b.getSum(time), blend) * s;
			default: throw "not implemented";
		}
		return 0.0;
	}

	public function getVector(pidx: Int=0, v: Value, time: Float, vec: h3d.Vector4) {
		switch(v) {
			case VMult(a, b):
				throw "need optimization";
			case VVector(x, y, z, null):
				vec.set(getFloat(pidx, x, time), getFloat(pidx, y, time), getFloat(pidx, z, time), 1.0);
			case VVector(x, y, z, w):
				vec.set(getFloat(pidx, x, time), getFloat(pidx, y, time), getFloat(pidx, z, time), getFloat(pidx, w, time));
			// case VHsl(h, s, l, a):
			// 	var hval = getFloat(pidx, h, time);
			// 	var sval = getFloat(pidx, s, time);
			// 	var lval = getFloat(pidx, l, time);
			// 	var aval = getFloat(pidx, a, time);
			// 	vec.makeColor(hval, sval, lval);
			// 	vec.a = aval;
			case VZero:
				vec.set(0,0,0,1);
			case VConst(v):
				vec.set(v, v, v, 1);
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
			case VConst(v):
				vec.set(v, v);
			default:
				var f = getFloat(pidx, v, time);
				vec.set(f, f);
		}
		return vec;
	}


	static var stats : {
		source: Map<String, Int>,
		opt: Map<String, Int>,
	}

	public static function beginStats() {
		stats = {
			source: new Map(),
			opt: new Map(),
		}
	}

	public static function endStats(path: String) {
		var sb = new StringBuf();

		function printStats(map: Map<String, Int>) {
			var sorted = [for(k => v in map) { k: k, v: v }];
			sorted.sort((a, b) -> b.v - a.v);
			for(item in sorted) {
				sb.add('\t${item.k}: ${item.v}\n');
			}
			sb.add('\n');
		}
		sb.add('-- Source values\n');
		printStats(stats.source);
		sb.add('-- Optimized values:\n');
		printStats(stats.opt);
		sys.io.File.saveContent(path, sb.toString());
		stats = null;
	}

	static function addStat(source: Value, opt: Value) {
		if(stats == null)
			return;
		function rec(v: Value) {
			return switch v {
				case VZero: "VZero";
				case VConst(v): "VConst";
				case VCurve(c): "VCurve";
				case VOptCurve(c, scale, offset): "VCurveScale";
				case VBlendCurves(_,_,_,_): 'VBlendCurves';
				case VParamRemap(a, param): 'VParamRemap(${rec(a)})';
				case VValueRemap(v, remap): 'VValueRemap(${rec(v)}, ${rec(remap)})';
				case VRandomBetweenCurves(idx, a, b): 'VRandomBetweenCurves';
				// case VRandom(idx, scale): 'VRandom(${rec(scale)})';
				case VRandom(idx, scale, add): 'VRandom';
				//case VAddRandomScale(idx, scale, add): 'VAddRandomScale';
				case VMultRandCurve(_): 'VMultRandCurve';
				case VAddRandCurve(_): 'VAddRandCurve';
				case VAdd(a, b): 'VAdd(${rec(a)}, ${rec(b)})';
				case VMult(a, b): 'VMult(${rec(a)}, ${rec(b)})';
				case VVector(x, y, z, w): 'VVector(${rec(x)}, ${rec(y)}, ${rec(z)}, ${rec(w)})';
				//case VHsl(h, s, l, a): 'VHsl(${rec(h)}, ${rec(s)}, ${rec(l)}, ${rec(a)})';
			}
		}

		function register(v: Value, map: Map<String, Int>) {
			function add(v: Value) {
				var str = rec(v);
				map.set(str, (map.get(str) ?? 0) + 1);
			}
			switch(v) {
				// Unpack root vectors for clarity
				case VVector(x, y, z, w):
					add(x);
					add(y);
					add(z);
					if(w != null) add(w);
				default:
					add(v);
			}
		}

		// if(rec(opt) != rec(source)) {
		// 	throw "??";
		// }
		register(opt, stats.opt);
		register(source, stats.source);
	}
}