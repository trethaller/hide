package hrt.prefab.fx;

// TODO: separate building values from compiled values
enum Value {
	VZero;
	VConst(v: Float);
	VCurve(c: Curve);
	VCurveScale(c: Curve, scale: Float, offset: Float);
	VBlend(a: Value, b: Value, blendVar: String);
	VParamRemap(a: Value, param: String);
	VValueRemap(v: Value, remap: Value);
	VRandomBetweenCurves(idx: Int, c: Curve);
	VRandom(idx: Int, scale: Value);
	VRandomScale(idx: Int, scale: Float);
	VAddRandomScale(idx: Int, scale: Float, add: Float);
	VAddRandCurve(cst: Float, ridx: Int, rscale: Float, c: Curve);
	VAdd(a: Value, b: Value);
	VMult(a: Value, b: Value);
	VVector(x: Value, y: Value, z: Value, ?w: Value);
	VBool(v: Value);
	VInt(v: Value);
}
