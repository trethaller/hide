Find a way to use this code:

/*
		if(Config.client) {

			function walkDir(directory: String, func: String->Void) {
				if (directory.indexOf("/.tmp/") != -1) return;
				if (sys.FileSystem.exists(directory)) {
					for (file in sys.FileSystem.readDirectory(directory)) {
						var path = haxe.io.Path.join([directory, file]);
						if (sys.FileSystem.isDirectory(path)) {
							var directory = haxe.io.Path.addTrailingSlash(path);
							walkDir(directory, func);
						}
						else {
							func(path);
						}
					}

				}
			}
/*
			function printRec(v: hrt.prefab.fx.Value) {
				return switch(v) {
					case null: "null";
					case VZero: "VConst";
					case VOne: "VConst";
					case VConst(v): "VConst";
					case VCurve(c): "VCurve";
					case VCurveScale(c, scale): 'VCurveScale';
					case VBlend(a, b, blendVar): 'VBlend(${printRec(a)}, ${printRec(b)})';
					case VParamRemap(a, param): 'VParamRemap(${printRec(a)})';
					case VValueRemap(v, remap): 'VValueRemap(${printRec(v)}, ${printRec(remap)})';
					case VRandomBetweenCurves(idx, c): 'VRandomBetweenCurves';
					case VRandom(idx, scale): 'VRandom(${printRec(scale)})';
					case VRandomScale(idx, scale): 'VRandomScale';
					case VAddRandomScale(idx, scale, add): 'VAddRandomScale';
					case VAddRandCurve(cst, ridx, rscale, c): 'VAddRandCurve';
					case VAdd(a, b): 'VAdd(${printRec(a)}, ${printRec(b)})';
					case VMult(a, b): 'VMult(${printRec(a)}, ${printRec(b)})';
					case VVector(x, y, z, w): 'VVector(${printRec(x)}, ${printRec(y)}, ${printRec(z)}, ${printRec(w)})';
					case VHsl(h, s, l, a): 'VHsl(${printRec(h)}, ${printRec(s)}, ${printRec(l)}, ${printRec(a)})';
					case VBool(v): 'VBool(${printRec(v)})';
					case VInt(v): 'VInt(${printRec(v)})';
				}
			}*/

/*
			var allFXs = [];
			walkDir("Res", function(path) {
				if(StringTools.endsWith(path, "fx")) {
					allFXs.push(path.substr(4));
				}
			});

			@:privateAccess {
				var combinations = new Map<String, Int>();

				for(fxpath in allFXs) {
					try {
						var dummy = new h3d.scene.Object();
						var fx = playFX(fxpath, dummy);
						var emitters = fx.findAll(o -> Std.downcast(o, hrt.prefab.fx.Emitter.EmitterObject));
						for(emitter in emitters) {
							var fields = Reflect.fields(emitter);
							for(field in fields) {
								var value : Dynamic = Reflect.field(emitter, field);
								if(Std.isOfType(value, hrt.prefab.fx.Value)) {
									var vv : hrt.prefab.fx.Value = cast value;
									inline function addCombination(v: hrt.prefab.fx.Value) {
										var str = printRec(v);
										combinations.set(str, (combinations.get(str) ?? 0) + 1);
									}
									switch(vv) {
										// case VVector(x, y, z, w):
										// 	addCombination(x);
										// 	addCombination(y);
										// 	addCombination(z);
										// 	addCombination(w);
										default:
											addCombination(vv);
									}
								}
							}
						}
					}
					catch(e: Dynamic) {
						trace('Error loading FX: $fxpath: $e');
					}
				}

				var lines = [];
				for(combination in combinations.keys()) {
					lines.push(combination + ": " + combinations.get(combination));
				}
				lines.sort((a, b) -> Reflect.compare(a, b));
				sys.io.File.saveContent("fx_combinations.txt", lines.join("\n"));
			}
		}*/