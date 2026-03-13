package hrt.prefab.fx;


private enum abstract FastValueType(Int) from Int to Int {
	var VZero = 0;
	var VConst = 1;
	var VRandom = 2;
	var VCurve = 3;
	var VCurveScale = 4;
	var VMultRandCurve = 5;
	var VAddRandCurve = 6;
	var VRandomBetweenCurves = 7;
	var VSlow = 8;
}

@:publicFields @:struct class FastValue {
	var type : FastValueType;
	var scale : Float;
	var offset : Float;
	var curveIdx : Int;
	var slow : Value;
	public function new(t: FastValueType) {
		this.type = t;
	}
}

typedef FastValues = #if hl hl.CArray<FastValue> #else Array<FastValue> #end;

abstract FastRef(Int) to Int {
	public inline function new(i : Int) {
		this = i;
	}

	inline public function next() : FastRef {
		return new FastRef(this + 1);
	}

	@:to inline function toBool() : Bool {
		return this >= 0;
	}
}


class Evaluator {
	public inline static final MAX_CURVES = 16;

	@:packed public var rnd: hxd.Rand;
	var fastValues : FastValues;
	var fastCount : Int;
	var pendingValues : Array<Value> = [];
	var curves : Array<Curve>;
	var randomCount = 0;
	var randoms : Array<Float>;
	var randIdx = 0;
	var maxInstances = 0;
	public var parameters: Map<String, Float> = [];

	public function new(count = 1){
		maxInstances = count;
	}

	public function setInstance(idx: Int) {
		setSeed(idx); // TODO use emitter seed
		randIdx = idx * randomCount;
		if(idx >= maxInstances)
			throw "Instance index out of bounds";
	}

	public function setSeed(seed: Int) {
		rnd.init(seed);
	}

	public function addFast(val: Value) : FastRef {
		switch(val) {
			case null | VZero: return new FastRef(-1);
			case VVector(x, y, z, w):
				var idx = pendingValues.length;
				pendingValues.push(x);
				pendingValues.push(y);
				pendingValues.push(z);
				pendingValues.push(w);
				return new FastRef(idx);
			default:
		}
		var ret = new FastRef(pendingValues.length);
		pendingValues.push(val);
		return ret;
	}

	function buildFast() {
		fastCount = pendingValues.length;
		curves = [];
		fastValues = hl.CArray.alloc(FastValue, fastCount);
		for(i in 0...fastCount) {
			fastValues.unsafeSet(i, mapFast(pendingValues[i]));
		}
		randoms = [for(i in 0...randomCount * maxInstances) hxd.Math.random()];
		pendingValues = null;
	}

	inline function prefetchCurve(c: Curve) {
		untyped $prefetch(c.curveData, 0);
	}

	public function prefetch() {
		for(c in curves)
			prefetchCurve(c);
	}

	function prefetchRef(ref: FastRef) {
		var fv = fastValues[ref];
		var curveIdx = fv.curveIdx;
		if(curveIdx >= 0) {
			var id1 = curveIdx & (MAX_CURVES - 1);
			prefetchCurve(curves[id1]);
			var id2 = curveIdx >> 4;
			if(id2 >= 0)
				prefetchCurve(curves[id2]);
		}
	}

	inline function getCurve(idx: Int, val: Float) {
		// TODO TOMR: RESTORE
		return val;
		// return curves[idx].getVal(val);
	}

	public function getFast(ref: FastRef, time: Float) : Float {
		var fv = fastValues[ref];
		return switch(fv.type) {
			case VZero:
				0.0;
			case VConst:
				fv.scale;
			case VRandom:
				random() * fv.scale + fv.offset;
			case VCurve:
				getCurve(fv.curveIdx, time);
			case VCurveScale:
				getCurve(fv.curveIdx, time) * fv.scale + fv.offset;
			case VMultRandCurve:
				(random() * fv.scale + fv.offset) * getCurve(fv.curveIdx, time);
			case VAddRandCurve:
				(random() * fv.scale + fv.offset) + getCurve(fv.curveIdx, time);
			case VRandomBetweenCurves:
				var a = getCurve(fv.curveIdx & (MAX_CURVES - 1), time);
				var b = getCurve(fv.curveIdx >> 4, time);
					a + (b - a) * random();
			case VSlow:
				getFloatSlow(fv.slow, time);
		};
	}

	inline public function getFastVec(ref: FastRef, time: Float, vec: h3d.Vector4) {
		var x = getFast(ref, time);
		ref = ref.next();
		var y = getFast(ref, time);
		ref = ref.next();
		var z = getFast(ref, time);
		ref = ref.next();
		var w = getFast(ref, time);
		vec.set(x, y, z, w);
	}

	function mapFast(val: Value) : FastValue {
		inline function addCurve(c: Curve) : Int {
			var idx = curves.length;
			if(idx >= MAX_CURVES)
				throw "Too many curves";
			curves.push(c);
			return idx;
		}
		inline function addRandom() {
			randomCount++;
		}
		inline function make(t: FastValueType, fn: FastValue -> Void) : FastValue {
			var f = new FastValue(t);
			fn(f);
			return f;
		}
		return switch(val) {
			case null|VZero:
				make(VZero, f -> {});
			case VConst(v):
				make(VConst, f -> f.scale = v);
			case VCurve(c):
				make(VCurve, f -> f.curveIdx = addCurve(c));
			case VOptCurve(c, scale, offset):
				make(VCurveScale, f -> {
					f.curveIdx = addCurve(c);
					f.scale = scale;
					f.offset = offset;
				});
			case VRandom(scale, add):
				make(VRandom, f -> {
					addRandom();
					f.scale = scale;
					f.offset = add;
				});
			case VMultRandCurve(rscale, cst, c):
				make(VMultRandCurve, f -> {
					addRandom();
					f.scale = rscale;
					f.offset = cst;
					f.curveIdx = addCurve(c);
				});
			case VAddRandCurve(rscale, cst, c):
				make(VAddRandCurve, f -> {
					addRandom();
					f.scale = rscale;
					f.offset = cst;
					f.curveIdx = addCurve(c);
				});
			case VRandomBetweenCurves(a, b):
				make(VRandomBetweenCurves, f -> {
					addRandom();
					var i1 = addCurve(a);
					var i2 = addCurve(b);
					f.curveIdx = i1 | (i2 << 4);
				});
			default:
				make(VSlow, f -> f.slow = val);
		}
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
		// return 0.5;
		return rnd.rand();
		//return randoms[randIdx++];
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
		numRands : Array<Int>,
		numCurves : Array<Int>,
		numKeys : Array<Int>,
	}

	public static function beginStats() {
		stats = {
			source: new Map(),
			opt: new Map(),
			numRands: [],
			numCurves: [],
			numKeys: [],
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
		sb.add('-- Num curves\n');
		for(i in 0...stats.numCurves.length) {
			sb.add('\t${i}: ${stats.numCurves[i]}\n');
		}
		sb.add('-- Num keys\n');
		for(i in 0...stats.numKeys.length) {
			sb.add('\t${i}: ${stats.numKeys[i]}\n');
		}
		sb.add('-- Num rands\n');
		for(i in 0...stats.numRands.length) {
			sb.add('\t${i}: ${stats.numRands[i]}\n');
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

		var numRands = 0;
		var numCurves = 0;
		var count = false;

		function addCurve(c: Curve) {
			if(!count) return;
			numCurves++;
			stats.numKeys[c.keys.length]++;
		}

		function rec(v: Value) {
			return switch v {
				case VZero: "VZero";
				case VConst(v): "VConst";
				case VCurve(c):
					addCurve(c);
					"VCurve";
				case VOptCurve(c, _, _):
					addCurve(c);
					"VOptCurve";
				case VBlendCurves(a,b,_,_):
					addCurve(a);
					addCurve(b);
					'VBlendCurves';
				case VParamRemap(a, _):
					'VParamRemap(${rec(a)})';
				case VValueRemap(v, remap):
					'VValueRemap(${rec(v)}, ${rec(remap)})';
				case VRandomBetweenCurves(a, b):
					addCurve(a);
					addCurve(b);
					if(count) numRands++;
					'VRandomBetweenCurves';
				case VRandom(scale, add):
					if(count) numRands++;
					'VRandom';
				case VMultRandCurve(_,_,c):
					addCurve(c);
					if(count) numRands++;
					'VMultRandCurve';
				case VAddRandCurve(_,_,c):
					addCurve(c);
					if(count) numRands++;
					'VAddRandCurve';
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
		count = true;
		register(opt, stats.opt);
		count = false;
		stats.numCurves[numCurves]++;
		stats.numRands[numRands]++;
		register(source, stats.source);
	}
}