package hrt.prefab.fx;

import hrt.prefab.Curve;
import hrt.prefab.fx.Value;
import hrt.prefab.fx.Evaluator;

typedef ParamDef = {
	> hrt.prefab.Props.PropDef,
	?animate: Bool,
	?instance: Bool,
	?groupName: String
}

class EmitterHelper {
	public static function randProp(name: String) {
		return name + "_rand";
	}

	public static function resetParam(props : Dynamic, param: ParamDef) {
		if(param.def is Array)
			Reflect.setField(props, param.name, cast(param.def, Array<Dynamic>).copy());
		else
			Reflect.setField(props, param.name, param.def);
	}

	public static function getParamVal(params: Map<String, ParamDef>, props: Dynamic, name: String, rand: Bool=false) : Dynamic {
		var param = params.get(name);
		if(param == null)
			return Reflect.field(props, name);
		var isVector = switch(param.t) {
			case PVec(_): true;
			default: false;
		}
		var val : Dynamic = rand ? (isVector ? [0.,0.,0.,0.] : 0.) : param.def;
		if(rand)
			name = EmitterHelper.randProp(name);
		if(props != null && Reflect.hasField(props, name)) {
			val = Reflect.field(props, name);
		}
		if(isVector)
			return h3d.Vector.fromArray(val);
		return val;
	}

	public static function makeParam(scope: Prefab, name: String, params: Map<String, ParamDef>, props: Dynamic, eval: hrt.prefab.fx.Evaluator): Value {
		var getCurve = hrt.prefab.Curve.getCurve.bind(scope);

		function makeCompVal(baseProp: Null<Float>, defVal: Float, randProp: Null<Float>, pname: String, suffix: String): Value {
			var offset = baseProp != null ? baseProp : defVal;
			var xVal = if (randProp != null && randProp != 0.0)
				VRandom(eval.nextRandIdx(), randProp, offset);
			else VConst(offset);

			var xCurve = getCurve(pname + suffix);
			if (xCurve != null) {
				if (xCurve.blendMode == CurveBlendMode.RandomBlend) {
					var c1 = Std.downcast(xCurve.children[0], Curve);
					var c2 = Std.downcast(xCurve.children[1], Curve);
					if(c1 != null && c2 != null)
						return VRandomBetweenCurves(eval.nextRandIdx(), c1, c2);
				}
				if (pname.indexOf("Rotation") >= 0 || pname.indexOf("Offset") >= 0)
				return VAdd(xVal, xCurve.makeVal());
			return VMult(xVal, xCurve.makeVal());
			}
			return xVal;
		}

		var baseProp: Dynamic = Reflect.field(props, name);
		var randProp: Dynamic = Reflect.field(props, EmitterHelper.randProp(name));
		var param = params.get(name);
		var v = switch (param.t) {
			case PVec(_):
				inline function makeComp(idx, suffix) {
					return makeCompVal(
						baseProp != null ? (baseProp[idx] : Float) : null,
						param.def != null ? param.def[idx] : 0.0,
						randProp != null ? (randProp[idx] : Float) : null,
						param.name, suffix);
				}
				VVector(
					makeComp(0, ":x"),
					makeComp(1, ":y"),
					makeComp(2, ":z"));

			default:
				makeCompVal(baseProp, param.def != null ? param.def : 0.0, randProp, param.name, "");
		}
		return Evaluator.optimize(v);
	}

	#if editor
	public static function generateEdit(params : Array<ParamDef>, instanceParams : Array<ParamDef>, props : Dynamic, properties : hide.comp.PropsEditor, onChange : (?pname : String) -> Void, refresh : Void -> Void) {
		// Emitter
		{
			// Sort by groupName
			var groupNames : Array<String> = [];
			for( p in params ) {
				if( p.groupName == null && groupNames.indexOf("Emitter") == -1 )
					groupNames.push("Emitter");
				else if( p.groupName != null && groupNames.indexOf(p.groupName) == -1 )
					groupNames.push(p.groupName);
			}

			for( gn in groupNames ) {
				var params = params.filter( p -> p.groupName == (gn == "Emitter" ? null : gn) );
				var group = new hide.Element('<div class="group" name="$gn"></div>');
				group.append(hide.comp.PropsEditor.makePropsList(params));
				properties.add(group, props, onChange);
			}
		}

		// Instances
		{
			var groups = new Map<String, Array<hrt.prefab.fx.EmitterHelper.ParamDef>>();
			for(p in instanceParams) {
				var groupName = p.groupName != null ? p.groupName : "Particles";

				if (!groups.exists(groupName))
					groups.set(groupName, []);
				groups[groupName].push(p);
			}

			for (groupName => params in groups)
			{
				var instGroup = new hide.Element('<div class="group" name="$groupName"></div>');
				var dl = new hide.Element('<dl>').appendTo(instGroup);

				for (p in params) {
					var dt = new hide.Element('<dt>${p.disp != null ? p.disp : p.name}</dt>').appendTo(dl);
					var dd = new hide.Element('<dd>').appendTo(dl);

					function addUndo(pname: String) {
						properties.undo.change(Field(props, pname, Reflect.field(props, pname)), function() {
							if(Reflect.field(props, pname) == null)
								Reflect.deleteField(props, pname);
							refresh();
						});
					}

					if(Reflect.hasField(props, p.name)) {
						hide.comp.PropsEditor.makePropEl(p, dd);
						dt.contextmenu(function(e) {
							e.preventDefault();
							hide.comp.ContextMenu.createFromEvent(cast e, [
								{ label : "Reset", click : function() {
									addUndo(p.name);
									EmitterHelper.resetParam(props, p);
									onChange();
									refresh();
								} },
								{ label : "Remove", click : function() {
									addUndo(p.name);
									Reflect.deleteField(props, p.name);
									onChange();
									refresh();
								} },
							]);
							return false;
						});
					}
					else {
						var btn = new hide.Element('<input type="button" value="+"></input>').appendTo(dd);
						btn.click(function(e) {
							addUndo(p.name);
							EmitterHelper.resetParam(props, p);
							refresh();
						});
					}
					var dt = new hide.Element('<dt>~</dt>').appendTo(dl);
					var dd = new hide.Element('<dd>').appendTo(dl);
					var randDef : Dynamic = switch(p.t) {
						case PVec(n): [for(i in 0...n) 0.0];
						case PFloat(_): 0.0;
						default: 0;
					};
					if(Reflect.hasField(props, EmitterHelper.randProp(p.name))) {
						hide.comp.PropsEditor.makePropEl({
							name: EmitterHelper.randProp(p.name),
							t: p.t,
							def: randDef}, dd);
						dt.contextmenu(function(e) {
							e.preventDefault();
							hide.comp.ContextMenu.createFromEvent(cast e, [
								{ label : "Reset", click : function() {
									addUndo(EmitterHelper.randProp(p.name));
									Reflect.setField(props, EmitterHelper.randProp(p.name), randDef);
									onChange();
									refresh();
								} },
								{ label : "Remove", click : function() {
									addUndo(EmitterHelper.randProp(p.name));
									Reflect.deleteField(props, EmitterHelper.randProp(p.name));
									onChange();
									refresh();
								} },
							]);
							return false;
						});
					}
					else {
						var btn = new hide.Element('<input type="button" value="+"></input>').appendTo(dd);
						btn.click(function(e) {
							addUndo(EmitterHelper.randProp(p.name));
							Reflect.setField(props, EmitterHelper.randProp(p.name), randDef);
							refresh();
						});
					}
				}

				properties.add(instGroup, props, onChange);
			}
		}
	}
	#end
}