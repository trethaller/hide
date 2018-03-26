package hide.ui;

typedef HideProps = {
	var autoSaveLayout : Null<Bool>;
	var layouts : Array<{ name : String, state : Dynamic }>;

	var currentProject : String;
	var recentProjects : Array<String>;

	var windowPos : { x : Int, y : Int, w : Int, h : Int, max : Bool };
	var renderer : String;
};

typedef PropsDef = {

	var hide : HideProps;

};

class Props {

	var ide : Ide;
	var parent : Props;
	public var path(default,null) : String;
	public var source(default, null) : PropsDef;
	public var current : PropsDef;

	public function new( ?parent : Props ) {
		ide = Ide.inst;
		this.parent = parent;
		sync();
	}

	public function load( path : String ) {
		this.path = path;
		var fullPath = ide.getPath(path);
		if( sys.FileSystem.exists(fullPath) )
			source = ide.parseJSON(sys.io.File.getContent(fullPath))
		else
			source = cast {};
		sync();
	}

	public function save() {
		sync();
		if( path == null ) throw "Cannot save properties (unknown path)";
		var fullPath = ide.getPath(path);
		if( Reflect.fields(source).length == 0 )
			try sys.FileSystem.deleteFile(fullPath) catch( e : Dynamic ) {};
		else
			sys.io.File.saveContent(fullPath, ide.toJSON(source));
	}

	public function sync() {
		if( parent != null ) parent.sync();
		current = cast {};
		if( parent != null ) merge(parent.current);
		if( source != null ) merge(source);
	}

	function merge( value : Dynamic ) {
		mergeRec(current, value);
	}

	function mergeRec( dst : Dynamic, src : Dynamic ) {
		for( f in Reflect.fields(src) ) {
			var v : Dynamic = Reflect.field(src,f);
			var t : Dynamic = Reflect.field(dst, f);
			if( Type.typeof(v) == TObject ) {
				if( t == null ) {
					t = {};
					Reflect.setField(dst, f, t);
				}
				mergeRec(t, v);
			} else if( v == null )
				Reflect.deleteField(dst, f);
			else
				Reflect.setField(dst,f,v);
		}
	}

	public function get( key : String ) : Dynamic {
		return Reflect.field(current,key);
	}

	public static function loadForProject( projectPath : String, resourcePath : String ) {
		var hidePath = Ide.inst.appPath;

		var defaults = new Props();
		defaults.load(hidePath + "/defaultProps.json");

		var userGlobals = new Props(defaults);
		userGlobals.load(hidePath + "/props.json");

		if( userGlobals.source.hide == null )
			userGlobals.source.hide = {
				autoSaveLayout : true,
				layouts : [],
				recentProjects : [],
				currentProject : projectPath,
				windowPos : null,
				renderer : null,
			};

		var perProject = new Props(userGlobals);
		perProject.load(resourcePath + "/props.json");

		var projectUserCustom = new Props(perProject);
		projectUserCustom.load(nw.App.dataPath + "/" + projectPath.split("/").join("_").split(":").join("_") + ".json");

		var current = new Props(projectUserCustom);

		return {
			global : userGlobals,
			project : perProject,
			user : projectUserCustom,
			current : current,
		};
	}

	public static function loadForFile( ide : hide.ui.Ide, path : String ) {
		var parts = path.split("/");
		var propFiles = [];
		var first = true, allowSave = false;
		while( true ) {
			var pfile = ide.getPath(parts.join("/") + "/props.json");
			if( sys.FileSystem.exists(pfile) ) {
				propFiles.unshift(pfile);
				if( first ) allowSave = true;
			}
			if( parts.length == 0 ) break;
			first = false;
			parts.pop();
		}
		var parent = ide.currentProps;
		for( p in propFiles ) {
			parent = new Props(parent);
			parent.load(p);
		}
		return allowSave ? parent : new Props(parent);
	}

}