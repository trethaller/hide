package hide.comp;

typedef ContextMenuItem = {
	var label : String;
	@:optional var menu : Array<ContextMenuItem>;
	@:optional var click : Void -> Void;
	@:optional var enabled : Bool;
	@:optional var checked : Bool;
	@:optional var isSeparator : Bool;
	@:optional var keys : {
		@:optional var key : String;
		@:optional var modifiers : String;
	};
}

class ContextMenu {

	static var MENUS : Array<nw.Menu>;
	static var COUNT = 0;

	public function new( config : Array<ContextMenuItem>, ?element: Element ) {
		if(element != null) {
			++COUNT;
			var id = Std.string(COUNT);
			element.attr("ctxmenu", id);
			var args = {
				selector: '[ctxmenu=${id}]',
				trigger: 'none',
				items: {
					"edit": {name: "Edit", icon: "edit"},
					"cut": {name: "Cut", icon: "cut"},
				   	'copy': {name: "Copy", icon: "copy"},
					"paste": {name: "Paste", icon: "paste"},
					"delete": {name: "Delete", icon: "delete"},
					"sep1": "---------",
					"quit": {name: "Quit", icon: function(){
						return 'context-menu-icon context-menu-icon-quit';
					}}
				}
			}
			untyped $.contextMenu(args);
			untyped $(element).contextMenu();
		}
		else {
			MENUS = [];
			var menu = makeMenu(config);
			var ide = hide.Ide.inst;
			// wait until mousedown to get correct mouse pos
			haxe.Timer.delay(function() {
				if( MENUS[0] == menu )
					menu.popup(ide.mouseX, ide.mouseY);
			},0);
		}
	}

	function makeMenu( config : Array<ContextMenuItem> ) {
		var m = new nw.Menu({type:ContextMenu});
		MENUS.push(m);
		for( i in config )
			m.append(makeMenuItem(i));
		return m;
	}

	function makeMenuItem(i:ContextMenuItem) {
		var mconf : nw.MenuItem.MenuItemOptions = { label : i.label, type : i.checked != null ? Checkbox : i.isSeparator ? Separator : Normal };
		if( i.keys != null ) {
			mconf.key = i.keys.key;
			mconf.modifiers = i.keys.modifiers;
		}
		if( i.menu != null ) mconf.submenu = makeMenu(i.menu);
		var m = new nw.MenuItem(mconf);
		if( i.checked != null ) m.checked = i.checked;
		if( i.enabled != null ) m.enabled = i.enabled;
		m.click = function() {
			try {
				i.click();
			} catch( e : Dynamic ) {
				hide.Ide.inst.error(e);
			}
		}
		return m;
	}

}