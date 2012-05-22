# This script allows a user to easily embed a **MtGox Dynamic Checkout Button**
# on their webpage just by using a special tag and including a Javascript file
#
# **Usage:**
# Add in the page an element using the following specification:
#
# 	<span class="mtgox"
#	      data-id="{transaction_id}" data-amount="{amount}"
#	      data-currency="{user_currency}">
#	      <!-- The following element is optionnal and is only here to
#	            provide a fallback if the user doesn't use javascript
#	      -->
#	      <a href="https://payment.mtgox.com/{transaction_id}">
#	        <img src="https://payment.mtgox.com/img/mtgox-checkout.png">
#	      </a>
# 	</span>
#
# ... then just include our javascript file, all the matching elements will be
# automatically replaced

#### Global variable declararation

# Contains our generated buttons
buttons = []
# Whether socket.io is loaded or not
sIoLoaded = false
# Whether we added the CSS or not
cssAdded = false
# CSS file
cssURI = "/dist/css/mtgox.min.css"
# MtGox + BTC logo
imgLogo = "https://payment.mtgox.com/img/button-logo.v4.png"
# Socket.io's host
socketIoHost = "https://socketio.mtgox.com:443"
# Retrieve the right "head" object
head = document.head or (document.getElementsByTagName("head"))[0] or document.documentElement
# list of currencies used by the buttons
buttonCurrencies = {}

#### Utility

# This class provides a set of static methods used mainly to manipulate objects or
# the DOM
class Utility
	# *static* **inArray**
	#
	# Check if value X is in array Y
	@inArray: (array, value) ->
		for item in array
			return true if item == value
		return false

	# *static* **getScript**
	#
	# Utility function to retrieve a script (ported from jQuery 1.7.2) and modified for our needs
	# We first create the element and attach a cross-browser handler for **onload**, if the handler
	# is called with success we remove the event handler to prevent a memory leak on IE and
	# destroy the element completely before calling the callback
	@getScript: (url, callback) ->
		script = document.createElement("script")
		script.type = "text/javascript"
		script.async = "async"
		script.onload = script.onreadystatechange = (_, isAbort) ->
			if isAbort or !script.readyState or /loaded|complete/.test(script.readyState)
				script.onload = script.onreadystatechange = null
				head.removeChild(script) if head and script.parentNode
				script = undefined
				callback(200, "success") if !isAbort
		script.src = url
		# Use insertBefore instead of appendChild to circumvent an IE6 bug
		head.insertBefore(script, head.firstChild)

	# *static* **getElementsByClassName**
	#
	# Cross-browser implementation of getElementsByClassName, using a fallback on the native
	# implementation if possible, then on querySelectorAll and finally on manually reading each
	# element for older browsers, this function was taken and modified from the now defunct
	# SwellJS library from Jonathan Gautheron <jgautheron@tenwa.pl> (https://github.com/jgautheron)
	# and Christophe Eblé
	@getElementsByClassName: (className, root = document.body, tagName = '') ->
		return root.getElementsByClassName(className) if document.getElementsByClassName

		if root.querySelectorAll?
			tagName = tagName or '';
			return root.querySelectorAll(tagName + '.' + className);

		tagName = tagName or '*'
		tags = root.getElementsByTagName(tagName)
		nodeList = []
		for tag in tags
			classes = (new MtGoxElement(tag)).getAttribute('class')
			nodeList.push(tag) if classes? and Utility.inArray(classes.split(" "), className)

		return nodeList

	@keys: (object) ->
		return Object.keys(object) if Object.keys?
		keys = []
		for key, value of object
			keys.push key
		return keys

#### MtGoxElement

# Provides a wrapper around HTML elements and augment them with useful cross-browser methods,
# also allows easy creation of new elements
class MtGoxElement
	# **Constructor**
	#
	# Just store the native DOM element
	constructor: (@element) ->

	# **hasAttribute**
	#
	# Check if the element as the attribute *attr* first by trying to call the native **hasAttribute**
	# method if it exists, or fallback to *object.attr*, return false on failure
	hasAttribute: (attr) ->
		if @element.hasAttribute?
			return @element.hasAttribute(attr)
		else
			return true if @element[attr]?
		return false

	# **getAttribute**
	#
	# Retrieve the value of the attribute *attr*, it first check if the attribute is named "class" and in that
	# case retrieve the *object.className* attribute instead (IE fix). It then try to use the native **getAttribute**
	# implementation and finally fallback on *object.attr*
	getAttribute: (attr) ->
		return @element.className if attr == 'class' and @element.className?
		if @element.getAttribute?
			return @element.getAttribute(attr)
		else
			return @element[attr] if @element[attr]?
		return null

	# **setAttribute**
	#
	# Set the value of the attribute *attr* to *value*, it first check if the attribute is named "class" and in that
	# case set the *object.className* attribute instead (IE fix). It then try to use the native **setAttribute**
	# implementation and finally fallback on setting *object.attr*
	setAttribute: (attr, value) ->
		@element.className = value if attr == 'class'
		if @element.setAttribute?
			return @element.setAttribute(attr, value)
		else
			@element[attr] = value
		return value

	# **appendChild**
	#
	# Append a child on the element
	appendChild: (elem) ->
		return @element.appendChild(elem.get())

	# **clean**
	#
	# Iterate on every childs and remove it
	clean: () ->
		while @element.childNodes.length
			@element.removeChild(@element.childNodes[0])

	# **get**
	#
	# Retrieve the native element
	get: () ->
		return @element

	# **setContent**
	#
	# Set the content of the element. For some unknown reason *innerText* didn't work on Firefox 11 so we
	# had to fallback on innerHTML
	setContent: (text) ->
		@element.innerHTML = text

	# *static* **create**
	#
	# Create a new element, set the attributes and optionally add it to the parent. The *name* attribute can be
	# written in the form tagName.className
	@create: (name, attributes, parent) ->
		attributes = {} if !attributes?

		if name.indexOf "."
			[name, classes...] = name.split(".")
			attributes["class"] = classes.join(" ")

		elem = new MtGoxElement(document.createElement(name))
		elem.setAttribute(attr, value) for attr, value of attributes

		if parent?
			parent.appendChild(elem)
		return elem

#### formatCurrency
currencies = {
	BTC: { symbol: 'BTC', format: "%v %s", precision: 3, rate: 1 },
	USD: { symbol: '$', format: "%s%v", precision: 2, rate: 5.06221 },
	EUR: { symbol: '&euro;', format: "%v%s", precision: 2, rate: 4.01817 },
	JPY: { symbol: '&yen;', format: "%s %v", precision: 0, rate: 401.098 },
	CAD: { symbol: 'CA$', format: "%s %v", precision: 2 },
	CNY: { symbol: '&yen;', format: "%s %v", precision: 2 },
	GBP: { symbol: '&pound;', format: "%s%v", precision: 2 },
}

# format number using accounting.js if available
formatCurrency = (amount, currency) ->
	currency = if currencies[currency]? then currencies[currency] else currencies['USD']
	precision_cent = Math.pow(10, currency.precision)
	amount = (Math.round(amount * precision_cent) / precision_cent).toString()
	isfloat = (amount.indexOf('.') >= 0)
	pad = 0
	base = parseInt(amount)
	decimal = amount - base
	if currency.precision > 0
		if !isfloat
			amount += '.'
		else
			pad = amount.length - amount.indexOf('.') - 1
		amount += (new Array((currency.precision + 1) - pad)).join('0')
	return currency.format.replace("%s", currency.symbol).replace("%v", amount)

convertCurrency = (amount, from, to) ->
	if from == 'BTC'
		currency = if currencies[to]? then currencies[to] else currencies['USD']
		return amount * currency.rate
	currency = if currencies[from]? then currencies[from] else currencies['USD']
	return amount / currency.rate

#### MtGoxSocket

# Encapsulate the Socket.IO functionnality
class MtGoxSocket
	# *static* **parseSIOMessage**
	#
	# Parse a packet from Socket.IO and redirect it to the correct handler
	@parseSIOMessage: (data) ->
		switch data.op
			when "private" then MtGoxSocket.parseSIOPrivate(data.private, data[data.private])

	# *static* **parseSIOPrivate**
	#
	# Parse a *private* packet and redirect to handler
	@parseSIOPrivate: (type, data) ->
		switch type
			when "ticker"
				currencies[data.buy.currency].rate = data.buy.value
				MtGoxSocket.updateButtons()

	# *static* **updateButtons**
	#
	# Get all the buttons on the page and update their current value based on the current ticker value
	@updateButtons: () =>
		for button in buttons
			base_val = button.btc_element.getAttribute('data-amount')
			base_cur = button.btc_element.getAttribute('data-currency')
			dist_cur = button.cur_element.getAttribute('data-currency')
			button.cur_element.setContent(formatCurrency convertCurrency(base_val, base_cur, dist_cur), dist_cur)

	# *static* **registerButtonUpdate**
	#
	# Called when Socket.IO is successfully embeded on the page and start listening for ticker events
	@registerButtonUpdate: () ->
		if window.io
			io = window.io
			socket = io.connect(socketIoHost + "/mtgox?Currency=" + Utility.keys(buttonCurrencies).join(',') + "&Channel=ticker")
			socket.on("message", MtGoxSocket.parseSIOMessage)

#### registerButton

# Our main method, takes a DOM element and create a checkout button inside.
# It first checks for socket.io to be loaded and insert our CSS file into the page's header,
# then we create the button using the following Jade Template:
#
#  	a.mtgox-button
# 	  div.mtgox-button-amount
# 	    span.mtgox-button-base(data-rel="428.50") 428.50 BTC
# 	    br
# 	    span.mtgox-button-dist US$ 2113.80
# 	    span.mtgox-button-logo
# 	      img(src="https://payment.mtgox.com/img/button-logo.png", width="88", height="33")
#
# Finally we empty the target element and append our button inside
registerButton = (element) ->
	return false if !element.nodeType?

	element = new MtGoxElement(element)

	# We need 3 things, the transaction id, the amount and the currency
	order_info = {}
	for attrName in ["data-id", "data-amount", "data-currency"]
		return false if !element.hasAttribute(attrName)
		order_info[attrName.replace("data-","")] = element.getAttribute(attrName)

	if order_info.currency == 'BTC'
		dest_cur = 'USD'
		buttonCurrencies['USD'] = true
	else
		dest_cur = 'BTC'
		buttonCurrencies[order_info.currency] = true

	payment_url    = "https://payment.mtgox.com/" + order_info.id

	elem_a = MtGoxElement.create("a.mtgox-button", {"href": payment_url, "target": "_blank" })

	elem_amount = MtGoxElement.create("span.mtgox-button-amount", {}, elem_a)

	btc_text = formatCurrency order_info.amount, order_info.currency
	btc_element = MtGoxElement.create("span.mtgox-button-base", {"data-amount": order_info.amount, "data-currency": order_info.currency}, elem_amount)
	btc_element.setContent(btc_text)

	MtGoxElement.create("br", {}, elem_amount)

	# Use the BTC amount in the currency element until we get the USD value on the ticker
	cur_element = MtGoxElement.create("span.mtgox-button-dist", {"data-currency": dest_cur}, elem_amount)
	cur_element.setContent(formatCurrency convertCurrency(order_info.amount, order_info.currency, dest_cur), dest_cur)

	elem_img_container = MtGoxElement.create("span.mtgox-button-logo", {}, elem_amount)

	img_attrs = {src: imgLogo}
	MtGoxElement.create("img", img_attrs, elem_img_container)

	# Finally remove element childs and add button to the DOM
	element.clean()
	element.appendChild(elem_a)

	# Register button into our global *buttons* variable
	buttons.push({ element: element, btc_element: btc_element, cur_element: cur_element })

#### Document onReady handler

# Handler for document "onReady", fire immediately if the document is alread ready
# *ie.* if the script is directly embedded in the DOM or loaded through AJAX
readyDone = false
findButtons = () ->
	return true if readyDone == true
	# load the CSS
	if !cssAdded
		cssAdded = true
		elem_attr =
			rel: "stylesheet",
			type: "text/css",
			href: cssURI
		elem_link = MtGoxElement.create("link", elem_attr)
		head.insertBefore(elem_link.get(), head.firstChild)
	# find every button
	registerButton(element) for element in Utility.getElementsByClassName('mtgox')
	# plug the socket.io
	if !sIoLoaded
		sIoLoaded = true
		Utility.getScript(socketIoHost + "/socket.io/socket.io.js", MtGoxSocket.registerButtonUpdate)
	readyDone = true

# Check for the document "readyness" and fire the above handler if necessary
if document.readyState == "complete"
	findButtons()
else
	# Support every possible onReady listeners
	if document.addEventListener?
		document.addEventListener("DOMContentLoaded", findButtons, false)
		document.addEventListener("load", findButtons, false)
	else
		document.attachEvent("onreadystatechange", findButtons)
		document.attachEvent("onload", findButtons)

#### Exports

# This is our namespace and public methods
mtgox =
	button: registerButton

# Export the namespace to the global object
window.MtGox = mtgox
