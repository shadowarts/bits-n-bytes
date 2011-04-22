/**
 * Copyright: 2010
 * Author: Andrew Alm
 */

var canvas_svg = function() {
	const __namespaces__ = {
		svg: 'http://www.w3.org/2000/svg',
		xlink: 'http://www.w3.org/1999/xlink'
	};

	function __extend__(dest, src) {
		for(var key in src)
			dest[key] = src[key];

		return dest;
	};

	function __apply__(instance, fn, args) {
		fn.apply(instance, args);
		return instance;
	};

	return function(_canvas) {
		var _instance = {};

		function _svg_node(name, attrs) {
			var elem = document.createElementNS(__namespaces__['svg'], 'svg:' + name);
			_canvas.appendChild(elem);
			return canvas_svg(elem).attr(attrs);
		};

		return (_instance = {
			define: function(fn) {
				return __apply__(_svg_node('defs', {}), fn);
			},

			style: function(attrs, fn) {
				return __apply__(_svg_node('g', __extend__({}, attrs)), fn);
			},

			group: function(id, attrs, fn) {
				return __apply__(_svg_node('g', __extend__({'id': id}, attrs)), fn);
			},

			circle: function(r, x, y, attrs) {
				return _svg_node('circle', 
					__extend__({'r': r, 'cx': x, 'cy': y}, attrs));
			},

			rect: function(x, y, w, h, attrs) {
				return _svg_node('rect', 
					__extend__({'x': x, 'y': y, 'width': w, 'height': h}, attrs));
			},

			line: function(x1, y1, x2, y2, attrs) {		
				return _svg_node('line', 
					__extend__({'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2}, attrs));
			},

			use: function(name, x, y, attrs) {
				return _svg_node('use', 
					__extend__({'xlink:href': name, 'x': x, 'y': y}, attrs));
			},

			attr: function(attrs) {
				for(key in attrs) {
					if(-1 != key.search(':'))
						_canvas.setAttributeNS(__namespaces__[key.split(':')[0]], key, attrs[key]);
					else
						_canvas.setAttribute(key, attrs[key]);
				}

				return _instance;
			},

			bind: function(name, fn) {
				_instance[name] = _canvas[name] = function(evt) {
					return __apply__(_instance, fn, [evt]);
				};

				return _instance;
			},

			remove: function() {
				_canvas.parentNode.removeChildNS(__namespaces__['svg', _canvas]);
			}
		});
	};
}();

