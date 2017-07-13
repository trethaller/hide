package hide.view;

@:access(hide.view.Particles3D)
class GpuParticles extends h3d.parts.GpuParticles {

	var parts : Particles3D;

	public function new(parts, parent) {
		super(parent);
		this.parts = parts;
	}

	override function loadTexture( path : String ) {
		return parts.scene.loadTextureFile(parts.state.path, path);
	}

}

class Particles3D extends FileView {

	var scene : hide.comp.Scene;
	var parts : GpuParticles;
	var properties : hide.comp.Properties;

	override function getDefaultContent() {
		var p = new h3d.parts.GpuParticles();
		p.addGroup().name = "Default";
		return haxe.io.Bytes.ofString(haxe.Json.stringify(p.save(),"\t"));
	}

	override function onDisplay( e : Element ) {
		properties = new hide.comp.Properties(e);
		scene = new hide.comp.Scene(properties.content);
		scene.onReady = init;
	}

	function addGroup( g : h3d.parts.GpuParticles.GpuPartGroup ) {
		var e = new Element('
			<div class="section open">
				<h1><span>${g.name}</span> &nbsp;<input type="checkbox" field="enable"/></h1>
				<div class="content">

					<div class="group" name="Display">
						<dl>
							<dt>Name</dt><dd><input field="name" onchange="$(this).closest(\'.section\').find(\'>h1 span\').text($(this).val())"/></dd>
							<dt>Texture</dt><dd><input type="file" accept="image/*"/></dd>
							<dt>Color Gradient</dt><dd><input type="file" accept="image/*"/></dd>
							<dt>Sort</dt><dd><select field="sortMode"></select></dd>
							<dt>3D&nbsp;Transform</dt><dd><input type="checkbox" field="transform3D"/></dd>
						</dl>
					</div>

					<div class="group" name="Emit">
						<dl>
							<dt>Mode</dt><dd><select field="emitMode"/></dd>
							<dt>Count</dt><dd><input type="range" field="nparts" min="0" max="1000" step="1"/></dd>
							<dt>Distance</dt><dd><input type="range" field="emitDist" min="0" max="10"/></dd>
							<dt>Angle</dt><dd><input type="range" field="emitAngle" min="${-Math.PI/2}" max="${Math.PI}"/></dd>
							<dt>Sync</dt><dd><input type="range" field="emitSync" min="0" max="1"/></dd>
							<dt>Delay</dt><dd><input type="range" field="emitDelay" min="0" max="10"/></dd>
							<dt>Loop</dt><dd><input type="checkbox" field="emitLoop"/></dd>
						</dl>
					</div>

					<div class="group" name="Life">
						<dl>
							<dt>Initial</dt><dd><input type="range" field="life" min="0" max="10"/></dd>
							<dt>Randomness</dt><dd><input type="range" field="lifeRand" min="0" max="1"/></dd>
							<dt>Fade In</dt><dd><input type="range" field="fadeIn" min="0" max="1"/></dd>
							<dt>Fade Out</dt><dd><input type="range" field="fadeOut" min="0" max="1"/></dd>
							<dt>Fade Power</dt><dd><input type="range" field="fadePower" min="0" max="3"/></dd>
						</dl>
					</div>

					<div class="group" name="Speed">
						<dl>
							<dt>Initial</dt><dd><input type="range" field="speed" min="0" max="10"/></dd>
							<dt>Randomness</dt><dd><input type="range" field="speedRand" min="0" max="1"/></dd>
							<dt>Acceleration</dt><dd><input type="range" field="speedIncr" min="-1" max="1"/></dd>
							<dt>Gravity</dt><dd><input type="range" field="gravity" min="-5" max="5"/></dd>
						</dl>
					</div>

					<div class="group" name="Size">
						<dl>
							<dt>Initial</dt><dd><input type="range" field="size" min="0.01" max="2"/></dd>
							<dt>Randomness</dt><dd><input type="range" field="sizeRand" min="0" max="1"/></dd>
							<dt>Growth</dt><dd><input type="range" field="sizeIncr" min="-1" max="1"/></dd>
						</dl>
					</div>

					<div class="group" name="Rotation">
						<dl>
							<dt>Initial</dt><dd><input type="range" field="rotInit" min="0" max="1"/></dd>
							<dt>Speed</dt><dd><input type="range" field="rotSpeed" min="0" max="5"/></dd>
							<dt>Randomness</dt><dd><input type="range" field="rotSpeedRand" min="0" max="1"/></dd>
						</dl>
					</div>

					<div class="group" name="Animation">
						<dl>
							<dt>Animation Repeat</dt><dd><input type="range" field="animationRepeat" min="0" max="10"/></dd>
							<dt>Frame Division</dt><dd>X <input type="number" field="frameDivisionX" min="1" max="16"/> Y <input type="number" field="frameDivisionY" min="1" max="16"/></dd>
							<dt>Frame Count</dt><dd><input type="number" field="frameCount" min="0" max="32"/></dd>
						</dl>
					</div>

				</div>
			</div>
		');
		e.find("h1").contextmenu(function(ev) {
			new hide.comp.ContextMenu([
				{ label : "Enable", checked : g.enable, click : function() { g.enable = !g.enable; e.find("[field=enable]").prop("checked", g.enable); } },
				{ label : "Delete", click : function() { parts.removeGroup(g); e.remove(); } },
			]);
			ev.preventDefault();
		});
		e.find("[field=emitLoop]").change(function(_) parts.currentTime = 0);
		properties.add(e,g);
	}

	function init() {
		new h3d.scene.CameraController(scene.s3d).loadFromCamera();
		parts = new GpuParticles(this,scene.s3d);
		parts.load(haxe.Json.parse(sys.io.File.getContent(getPath())));

		for( g in parts.getGroups() )
			addGroup(g);
		var but = new Element('<input type="button" value="New Group"/>');
		but.appendTo(properties.panel);
		but.click(function(_) {
			var g = parts.addGroup();
			g.name = "Group#" + Lambda.count({ iterator : parts.getGroups });
			addGroup(g);
			but.appendTo(properties.panel);
		},null);
	}

	static var _ = FileTree.registerExtension(Particles3D, ["json.particles3D"], { icon : "snowflake-o", createNew: "Particle 3D" });

}