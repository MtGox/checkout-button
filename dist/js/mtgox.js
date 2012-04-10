(function() {
  var MtGoxElement, MtGoxSocket, Utility, buttons, cssAdded, cssURI, findButtons, head, imgLogo, mtgox, readyDone, registerButton, sIoLoaded, socketIoHost,
    __slice = Array.prototype.slice;

  buttons = [];

  sIoLoaded = false;

  cssAdded = false;

  cssURI = "https://payment.mtgox.com/css/mtgox.min.css";

  imgLogo = "https://payment.mtgox.com/img/button-logo.png";

  socketIoHost = "https://socketio.mtgox.com:443";

  head = document.head || (document.getElementsByTagName("head"))[0] || document.documentElement;

  Utility = (function() {

    function Utility() {}

    Utility.inArray = function(array, value) {
      var item, _i, _len;
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        item = array[_i];
        if (item === value) return true;
      }
      return false;
    };

    Utility.getScript = function(url, callback) {
      var script;
      script = document.createElement("script");
      script.type = "text/javascript";
      script.async = "async";
      script.onload = script.onreadystatechange = function(_, isAbort) {
        if (isAbort || !script.readyState || /loaded|complete/.test(script.readyState)) {
          script.onload = script.onreadystatechange = null;
          if (head && script.parentNode) head.removeChild(script);
          script = void 0;
          if (!isAbort) return callback(200, "success");
        }
      };
      script.src = url;
      return head.insertBefore(script, head.firstChild);
    };

    Utility.getElementsByClassName = function(className, root, tagName) {
      var classes, nodeList, tag, tags, _i, _len;
      if (root == null) root = document.body;
      if (tagName == null) tagName = '';
      if (document.getElementsByClassName) {
        return root.getElementsByClassName(className);
      }
      if (root.querySelectorAll != null) {
        tagName = tagName || '';
        return root.querySelectorAll(tagName + '.' + className);
      }
      tagName = tagName || '*';
      tags = root.getElementsByTagName(tagName);
      nodeList = [];
      for (_i = 0, _len = tags.length; _i < _len; _i++) {
        tag = tags[_i];
        classes = (new MtGoxElement(tag)).getAttribute('class');
        if ((classes != null) && Utility.inArray(classes.split(" "), className)) {
          nodeList.push(tag);
        }
      }
      return nodeList;
    };

    return Utility;

  })();

  MtGoxElement = (function() {

    function MtGoxElement(element) {
      this.element = element;
    }

    MtGoxElement.prototype.hasAttribute = function(attr) {
      if (this.element.hasAttribute != null) {
        return this.element.hasAttribute(attr);
      } else {
        if (this.element[attr] != null) return true;
      }
      return false;
    };

    MtGoxElement.prototype.getAttribute = function(attr) {
      if (attr === 'class' && (this.element.className != null)) {
        return this.element.className;
      }
      if (this.element.getAttribute != null) {
        return this.element.getAttribute(attr);
      } else {
        if (this.element[attr] != null) return this.element[attr];
      }
      return null;
    };

    MtGoxElement.prototype.setAttribute = function(attr, value) {
      if (attr === 'class') this.element.className = value;
      if (this.element.setAttribute != null) {
        return this.element.setAttribute(attr, value);
      } else {
        this.element[attr] = value;
      }
      return value;
    };

    MtGoxElement.prototype.appendChild = function(elem) {
      return this.element.appendChild(elem.get());
    };

    MtGoxElement.prototype.clean = function() {
      var _results;
      _results = [];
      while (this.element.childNodes.length) {
        _results.push(this.element.removeChild(this.element.childNodes[0]));
      }
      return _results;
    };

    MtGoxElement.prototype.get = function() {
      return this.element;
    };

    MtGoxElement.prototype.setContent = function(text) {
      return this.element.innerHTML = text;
    };

    MtGoxElement.create = function(name, attributes, parent) {
      var attr, classes, elem, value, _ref;
      if (!(attributes != null)) attributes = {};
      if (name.indexOf(".")) {
        _ref = name.split("."), name = _ref[0], classes = 2 <= _ref.length ? __slice.call(_ref, 1) : [];
        attributes["class"] = classes.join(" ");
      }
      elem = new MtGoxElement(document.createElement(name));
      for (attr in attributes) {
        value = attributes[attr];
        elem.setAttribute(attr, value);
      }
      if (parent != null) parent.appendChild(elem);
      return elem;
    };

    return MtGoxElement;

  })();

  MtGoxSocket = (function() {

    function MtGoxSocket() {}

    MtGoxSocket.parseSIOMessage = function(data) {
      switch (data.op) {
        case "private":
          return MtGoxSocket.parseSIOPrivate(data.private, data[data.private]);
      }
    };

    MtGoxSocket.parseSIOPrivate = function(type, data) {
      switch (type) {
        case "ticker":
          return MtGoxSocket.updateButtons(data.last_all.value);
      }
    };

    MtGoxSocket.updateButtons = function(btc_value) {
      var btc_val, button, cur_val, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = buttons.length; _i < _len; _i++) {
        button = buttons[_i];
        btc_val = button.btc_element.getAttribute('data-amount');
        cur_val = Math.round(btc_val * btc_value * 100) / 100;
        _results.push(button.cur_element.setContent('US$ ' + cur_val));
      }
      return _results;
    };

    MtGoxSocket.registerButtonUpdate = function() {
      var io, socket;
      if (window.io) {
        io = window.io;
        socket = io.connect(socketIoHost + "/mtgox?Currency=USD&Channel=ticker");
        return socket.on("message", MtGoxSocket.parseSIOMessage);
      }
    };

    return MtGoxSocket;

  })();

  registerButton = function(element) {
    var attrName, btc_element, btc_text, cur_element, elem_a, elem_amount, elem_attr, elem_img_container, elem_link, img_attrs, order_info, payment_url, _i, _len, _ref;
    if (!(element.nodeType != null)) return false;
    if (!sIoLoaded) {
      sIoLoaded = true;
      Utility.getScript(socketIoHost + "/socket.io/socket.io.js", MtGoxSocket.registerButtonUpdate);
    }
    if (!cssAdded) {
      cssAdded = true;
      elem_attr = {
        rel: "stylesheet",
        type: "text/css",
        href: cssURI
      };
      elem_link = MtGoxElement.create("link", elem_attr);
      head.insertBefore(elem_link.get(), head.firstChild);
    }
    element = new MtGoxElement(element);
    order_info = {};
    _ref = ["data-id", "data-amount", "data-currency"];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      attrName = _ref[_i];
      if (!element.hasAttribute(attrName)) return false;
      order_info[attrName.replace("data-", "")] = element.getAttribute(attrName);
    }
    payment_url = "https://payment.mtgox.com/" + order_info.id;
    elem_a = MtGoxElement.create("a.mtgox-button", {
      "href": payment_url,
      "target": "_blank"
    });
    elem_amount = MtGoxElement.create("div.mtgox-button-amount", {}, elem_a);
    btc_text = order_info.amount + " " + order_info.currency;
    btc_element = MtGoxElement.create("span.mtgox-button-btc", {
      "data-amount": order_info.amount
    }, elem_amount);
    btc_element.setContent(btc_text);
    MtGoxElement.create("br", {}, elem_amount);
    cur_element = MtGoxElement.create("span.mtgox-button-cur", {}, elem_amount);
    cur_element.setContent(btc_text);
    elem_img_container = MtGoxElement.create("span.mtgox-button-logo", {}, elem_amount);
    img_attrs = {
      src: imgLogo,
      width: "88",
      height: "33"
    };
    MtGoxElement.create("img", img_attrs, elem_img_container);
    element.clean();
    element.appendChild(elem_a);
    return buttons.push({
      element: element,
      btc_element: btc_element,
      cur_element: cur_element
    });
  };

  readyDone = false;

  findButtons = function() {
    var element, _i, _len, _ref;
    if (readyDone === true) return true;
    _ref = Utility.getElementsByClassName('mtgox');
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      element = _ref[_i];
      registerButton(element);
    }
    return readyDone = true;
  };

  if (document.readyState === "complete") {
    findButtons();
  } else {
    if (document.addEventListener != null) {
      document.addEventListener("DOMContentLoaded", findButtons, false);
      document.addEventListener("load", findButtons, false);
    } else {
      document.attachEvent("onreadystatechange", findButtons);
      document.attachEvent("onload", findButtons);
    }
  }

  mtgox = {
    button: registerButton
  };

  window.MtGox = mtgox;

}).call(this);
