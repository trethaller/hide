package hrt.prefab.fx;


private enum abstract FastValueType(Int) from Int to Int {
	var VZero = 0;
	var VConst = 1;
	var VCurveScale = 2;
	var VRandom = 3;
	var VCurve = 4;
	var VMultRandCurve = 5;
	var VBlendCurves = 6;
	var VAddRandCurve = 7;
	var VRandomBetweenCurves = 8;
	var VSlow;
}

class FastValue {
	var type : FastValueType;
	var idx : Int;
	var scale : Float;
	var offset : Float;
	var curve1 : Curve;
	var curve2 : Curve;
	var slow : Value;
}

class Evaluator {
	public var rnd: hxd.Rand;
	public var parameters: Map<String, Float> = [];

	public function new() {
		this.rnd = new hxd.Rand(0);
	}

	public function setSeed(seed: Int) {
		rnd.init(seed);
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
						case VRandom(rs, add): VMultRandCurve(rs, add, c);
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
						case VRandom(rs, add): VAddRandCurve(rs, add, c);
						default: null;
					}
					case VConst(va): switch(y) {
						case VConst(vb): VConst(va + vb);
						case VRandom(rs, ra): VRandom(rs, ra + va);
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
				default: v;
			}
		}

		var r = opt(val);
		addStat(val, r);
		return r;
	}

	inline function random() {
		return rnd.rand();
	}

	public function setAllParameters(params: Array<hrt.prefab.fx.FX.Parameter>) {
		parameters.clear();
		if (params == null)
			return;
		for (p in params)
			parameters[p.name] = p.def;
	}

	function getFloatSlow(val: Value, time: Float) : Float {
		return switch(val) {
			case VCurve(c):  c.getVal(time);
			case VOptCurve(c, scale, offset): c.getVal(time) * scale + offset;
			case VMultRandCurve(rscale, radd, c): (random() * rscale + radd) * c.getVal(time);
			case VAddRandCurve(rscale, radd, c): (random() * rscale + radd) + c.getVal(time);
		case VBlendCurves(a,b,v,s):
			var blend = parameters[v] ?? 0.0;
			return hxd.Math.lerp(a.getVal(time), b.getVal(time), blend) * s;
		case VParamRemap(a, param):
			var time = parameters[param] ?? 0.0;
			return getFloatSlow(a, time);
			case VValueRemap(a, remap):
				var time = getFloatSlow(remap, time);
				return getFloatSlow(a, time);
			case VRandomBetweenCurves(c1, c2):
				var a = c1.getVal(time);
				var b = c2.getVal(time);
				return a + (b - a) * random();
			case VMult(a, b):
				return getFloatSlow(a, time) * getFloatSlow(b, time);
			case VAdd(a, b):
				return getFloatSlow(a, time) + getFloatSlow(b, time);
			default:
				return getFloat(val, time);
		}
	}

	inline public function getFloat(val: Value, time: Float) : Float {
		return switch(val) {
			case VZero: return 0.0;
			case VConst(v): v;
			case VRandom(scale, add): random() * scale + add;
			default:
				getFloatSlow(val, time);
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

	public function getVector(v: Value, time: Float, vec: h3d.Vector4) {
		switch(v) {
			case VMult(a, b):
				throw "need optimization";
			case VVector(x, y, z, null):
				vec.set(getFloat(x, time), getFloat(y, time), getFloat(z, time), 1.0);
			case VVector(x, y, z, w):
				vec.set(getFloat(x, time), getFloat(y, time), getFloat(z, time), getFloat(w, time));
			case VZero:
				vec.set(0,0,0,1);
			case VConst(v):
				vec.set(v, v, v, 1);
			default:
				var f = getFloat(v, time);
				vec.set(f, f, f, 1.0);
		}
		return vec;
	}

	public function getVector2(v: Value, time: Float, vec: h2d.col.Point) {
		switch(v) {
			case VMult(a, b):
				throw "need optimization";
			case VVector(x, y, z, null):
				vec.set(getFloat(x, time), getFloat(y, time));
			case VVector(x, y, z, w):
				vec.set(getFloat(x, time), getFloat(y, time));
			case VZero:
				vec.set(0,0);
			case VConst(v):
				vec.set(v, v);
			default:
				var f = getFloat(v, time);
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
				case VParamRemap(a, _): 'VParamRemap(${rec(a)})';
				case VValueRemap(v, remap): 'VValueRemap(${rec(v)}, ${rec(remap)})';
			case VRandomBetweenCurves(a, b): 'VRandomBetweenCurves';
			case VRandom(scale, add): 'VRandom';
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