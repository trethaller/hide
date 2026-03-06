package hrt.prefab.fx;

// TODO: separate building values from compiled values
enum Value {
	VZero;
	VConst(v: Float);
	VCurve(c: Curve);
	VOptCurve(c: Curve, scale: Float, offset: Float);
	VBlendCurves(a: Curve, b: Curve, blendVar: String, scale: Float);
	VParamRemap(a: Value, param: String);
	VValueRemap(v: Value, remap: Value);
	VRandomBetweenCurves(idx: Int, a: Curve, b: Curve);
	VRandom(idx: Int, scale: Float, add: Float);
	VMultRandCurve(ridx: Int, rscale: Float, cst: Float, c: Curve);
	VAdd(a: Value, b: Value);
	VMult(a: Value, b: Value);
	VVector(x: Value, y: Value, z: Value, ?w: Value);
}
