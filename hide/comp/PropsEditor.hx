package hide.comp;

enum PropType {
	PInt( ?min : Int, ?max : Int );
	PFloat( ?min : Float, ?max : Float );
	PVec( n : Int );
	PBool;
	PTexture;
	PUnsupported( debug : String );
}

class PropsEditor extends Component {

	public var undo : hide.ui.UndoHistory;
	public var lastChange : Float = 0.;
	public var fields(default, null) : Array<PropsField>;

	public function new(root,?undo) {
		super(root);
		root.addClass("hide-properties");
		this.undo = undo == null ? new hide.ui.UndoHistory() : undo;
		fields = [];
	}

	public function clear() {
		root.empty();
		fields = [];
	}

	public function addMaterial( m : h3d.mat.Material, ?parent : Element, ?onChange ) {
		var props = m.props;
		var def = h3d.mat.MaterialSetup.current.editMaterial(props);
		def = add(def, props, function(name) {
			if( m.model != null )
				h3d.mat.MaterialSetup.current.saveModelMaterial(m);
			m.refreshProps();
			def.remove();
			addMaterial(m, parent, onChange);
			if( onChange != null ) onChange(name);
		});
		if( parent != null && parent.length != 0 )
			def.appendTo(parent);
	}

	public function addProps( props : Array<{ name : String, t : PropType }>, context : Dynamic ) {
		var e = new Element('<dl>');
		for( p in props ) {
			new Element('<dt>${p.name}</dt>').appendTo(e);
			var def = new Element('<dd>').appendTo(e);
			switch( p.t ) {
			case PInt(min, max):
				var e = new Element('<input type="range" field="${p.name}" step="1">').appendTo(def);
				if( min != null ) e.attr("min", "" + min);
				e.attr("max", "" + (max == null ? 100 : max));
			case PFloat(min, max):
				var e = new Element('<input type="range" field="${p.name}">').appendTo(def);
				if( min != null ) e.attr("min", "" + min);
				if( max != null ) e.attr("max", "" + max);
			case PBool:
				new Element('<input type="checkbox" field="${p.name}">').appendTo(def);
			case PTexture:
				new Element('<input type="texturepath" field="${p.name}">').appendTo(def);
			case PUnsupported(text):
				new Element('<font color="red">' + StringTools.htmlEscape(text) + '</font>').appendTo(def);
			case PVec(n):
				var isColor = p.name.toLowerCase().indexOf("color") >= 0;
				var names = isColor ? ["r", "g", "b", "a"] : ["x", "y", "z", "w"];
				for( i in 0...n ) {
					var div = new Element('<div>').appendTo(def);
					new Element('<span>${names[i]} </span>').appendTo(div);
					var e = new Element('<input type="range" class="small" field="${p.name}.$i">').appendTo(div);
					e.attr("min", isColor ? "0" : "-1");
					e.attr("max", "1");
				}
			}
		}
		return add(e, context);
	}

	public function add( e : Element, ?context : Dynamic, ?onChange : String -> Void ) {

		e.appendTo(root);
		e = e.wrap("<div></div>").parent(); // necessary to have find working on top level element

		e.find("input[type=checkbox]").wrap("<div class='checkbox-wrapper'></div>");
		e.find("input[type=range]").not("[step]").attr("step", "any");

		// -- reload states ---
		for( h in e.find(".section > h1").elements() )
			if( getDisplayState("section:" + StringTools.trim(h.text())) != false )
				h.parent().addClass("open");

		for( group in e.find(".group").elements() ) {
			var s = group.closest(".section");
			var key = (s.length == 0 ? "" : StringTools.trim(s.children("h1").text()) + "/") + group.attr("name");
			if( getDisplayState("group:" + key) != false )
				group.addClass("open");
		}

		// init section
		e.find(".section").not(".open").children(".content").hide();
		e.find(".section > h1").mousedown(function(e) {
			if( e.button != 0 ) return;
			var section = e.getThis().parent();
			section.toggleClass("open");
			section.children(".content").slideToggle(100);
			saveDisplayState("section:" + StringTools.trim(e.getThis().text()), section.hasClass("open"));
		}).find("input").mousedown(function(e) e.stopPropagation());

		for( g in e.find(".group").elements() ) {
			g.wrapInner("<div class='content'></div>");
			if( g.attr("name") != null ) new Element("<div class='title'>" + g.attr("name") + '</div>').prependTo(g);
		}

		// init group
		e.find(".group").not(".open").children(".content").hide();
		e.find(".group > .title").mousedown(function(e) {
			if( e.button != 0 ) return;
			var group = e.getThis().parent();
			group.toggleClass("open");
			group.children(".content").slideToggle(100);

			var s = group.closest(".section");
			var key = (s.length == 0 ? "" : StringTools.trim(s.children("h1").text()) + "/") + group.attr("name");
			saveDisplayState("group:" + key, group.hasClass("open"));

		}).find("input").mousedown(function(e) e.stopPropagation());

		// init input reflection
		for( f in e.find("[field]").elements() ) {
			var f = new PropsField(this, f, context);
			f.onChange = function(undo) {
				lastChange = haxe.Timer.stamp();
				if( onChange != null ) onChange(@:privateAccess f.fname);
			};
			fields.push(f);
		}

		return e;
	}

}


class PropsField extends Component {

	public var fname : String;
	var props : PropsEditor;
	var context : Dynamic;
	var current : Dynamic;
	var enumValue : Enum<Dynamic>;
	var tempChange : Bool;
	var beforeTempChange : { value : Dynamic };
	var tselect : hide.comp.TextureSelect;
	var fselect : hide.comp.FileSelect;
	var viewRoot : Element;
	var range : hide.comp.Range;

	public function new(props, f, context) {
		super(f);
		viewRoot = root.closest(".lm_content");
		this.props = props;
		this.context = context;
		Reflect.setField(f[0],"propsField", this);
		fname = f.attr("field");
		current = getFieldValue();
		switch( f.attr("type") ) {
		case "checkbox":
			f.prop("checked", current);
			f.change(function(_) {
				undo(function() {
					var f = resolveField();
					f.current = getFieldValue();
					f.root.prop("checked", f.current);
					f.onChange(true);
				});
				current = f.prop("checked");
				setFieldValue(current);
				onChange(false);
			});
			return;
		case "texture":
			f.addClass("file");
			tselect = new hide.comp.TextureSelect(f);
			tselect.value = current;
			tselect.onChange = function() {
				undo(function() {
					var f = resolveField();
					f.current = getFieldValue();
					f.tselect.value = f.current;
					f.onChange(true);
				});
				current = tselect.value;
				setFieldValue(current);
				onChange(false);
			}
			return;
		case "texturepath":
			f.addClass("file");
			tselect = new hide.comp.TextureSelect(f);
			tselect.path = current;
			tselect.onChange = function() {
				undo(function() {
					var f = resolveField();
					f.current = getFieldValue();
					f.tselect.path = f.current;
					f.onChange(true);
				});
				current = tselect.path;
				setFieldValue(current);
				onChange(false);
			}
			return;
		case "model":
			f.addClass("file");
			fselect = new hide.comp.FileSelect(f, ["hmd", "fbx"]);
			fselect.path = current;
			fselect.onChange = function() {
				undo(function() {
					var f = resolveField();
					f.current = getFieldValue();
					f.fselect.path = f.current;
					f.onChange(true);
				});
				current = fselect.path;
				setFieldValue(current);
				onChange(false);
			};
			return;
		case "range":
			range = new hide.comp.Range(f);
			range.value = current;
			range.onChange = function(temp) {
				tempChange = temp;
				setVal(range.value);
			};
			return;
		default:
			if( f.is("select") ) {
				enumValue = Type.getEnum(current);
				if( enumValue != null && f.find("option").length == 0 ) {
					for( c in enumValue.getConstructors() )
						new Element('<option value="$c">$c</option>').appendTo(f);
				}
			}

			f.val(current);
			f.keyup(function(e) {
				if( e.keyCode == 13 ) {
					f.blur();
					return;
				}
				if( e.keyCode == 27 ) {
					f.blur();
					return;
				}
				tempChange = true;
				f.change();
			});
			f.change(function(e) {

				var newVal : Dynamic = f.val();

				if( f.is("[type=number]") )
					newVal = Std.parseFloat(newVal);

				if( enumValue != null )
					newVal = Type.createEnum(enumValue, newVal);

				if( f.is("select") )
					f.blur();

				setVal(newVal);
			});
		}
	}

	function getAccess() : { obj : Dynamic, index : Int, name : String } {
		var obj : Dynamic = context;
		var path = fname.split(".");
		var field = path.pop();
		for( p in path ) {
			var index = Std.parseInt(p);
			if( index != null )
				obj = obj[index];
			else
				obj = Reflect.getProperty(obj, p);
		}
		var index = Std.parseInt(field);
		if( index != null )
			return { obj : obj, index : index, name : null };
		return { obj : obj, index : -1, name : field };
	}


	function getFieldValue() {
		var a = getAccess();
		if( a.name != null )
			return Reflect.getProperty(a.obj, a.name);
		return a.obj[a.index];
	}

	function setFieldValue( value : Dynamic ) {
		var a = getAccess();
		if( a.name != null )
			Reflect.setProperty(a.obj, a.name, value);
		else
			a.obj[a.index] = value;
	}

	function undo( f : Void -> Void ) {
		var a = getAccess();
		if( a.name != null )
			props.undo.change(Field(a.obj, a.name, current), f);
		else
			props.undo.change(Array(a.obj, a.index, current), f);
	}

	function setVal(v) {
		if( current == v ) {
			// delay history save until last change
			if( tempChange || beforeTempChange == null )
				return;
			current = beforeTempChange.value;
			beforeTempChange = null;
		}
		if( tempChange ) {
			tempChange = false;
			if( beforeTempChange == null ) beforeTempChange = { value : current };
		} else {
			undo(function() {
				var f = resolveField();
				var v = getFieldValue();
				f.current = v;
				f.root.val(v);
				f.root.parent().find("input[type=text]").val(v);
				f.onChange(true);
			});
		}
		current = v;
		setFieldValue(v);
		onChange(false);
	}

	public dynamic function onChange( wasUndo : Bool ) {
	}

	function resolveField() {
		/*
			If our panel has been removed but another bound to the same object has replaced it (a refresh for instance)
			let's try to locate the field with same context + name to refresh it instead
		*/

		for( f in viewRoot.find("[field]") ) {
			var p : PropsField = Reflect.field(f, "propsField");
			if( p != null && p.context == context && p.fname == fname )
				return p;
		}

		return this;
	}

}
