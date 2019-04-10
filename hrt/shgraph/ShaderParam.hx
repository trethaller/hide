package hrt.shgraph;

import hide.Element;
import hxsl.*;

using hxsl.Ast;

@name("Param")
@description("Parameters inputs, it's dynamic")
@group("Input")
@noheader()
class ShaderParam extends ShaderNode {

	@output() var output = SType.Variant;

	@param("Variable") public var variable : TVar;

	override public function getOutput(key : String) : TVar {
		return variable;
	}

	override public function build(key : String) : TExpr {
		return null;
	}

	override public function loadProperties(props : Dynamic) {
		var paramVariable : String = Reflect.field(props, "variable");

		for (c in ShaderNode.availableVariables) {
			if (c.name == paramVariable) {
				this.variable = c;
				return;
			}
		}
	}

	override public function saveProperties() : Dynamic {
		var parameters = {
			variable: variable.name
		};

		return parameters;
	}

	#if editor
	override public function getPropertiesHTML(width : Float) : Array<Element> {
		var elements = super.getPropertiesHTML(width);
		var element = new Element('<div style="width: 110px; height: 30px"></div>');
		element.append(new Element('<select id="variable"></select>'));

		if (this.variable == null) {
			this.variable = ShaderNode.availableVariables[0];
		}
		var input = element.children("select");
		var indexOption = 0;
		for (c in ShaderNode.availableVariables) {
			input.append(new Element('<option value="${indexOption}">${c.name}</option>'));
			if (this.variable.name == c.name) {
				input.val(indexOption);
			}
			indexOption++;
		}
		input.on("change", function(e) {
			var value = input.val();
			this.variable = ShaderNode.availableVariables[value];
		});


		elements.push(element);

		return elements;
	}
	#end

}