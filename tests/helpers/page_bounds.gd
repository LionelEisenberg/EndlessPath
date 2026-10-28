class_name PageBounds
extends RefCounted

## PageBounds
## Test helper for the inventory's pressed pages. It knows where the two pages'
## paper lies on the 1920x1080 screen, and finds printed text that is drawn at
## another scale than the screen's (the double-size text of the old book) or
## that spills off the paper. Only visible Labels and RichTextLabels count.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

## The left page inside its border line, in screen px.
const LEFT_PAGE: Rect2 = Rect2(424, 202, 508, 688)

## The right page inside its border line, in screen px.
const RIGHT_PAGE: Rect2 = Rect2(988, 202, 508, 688)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Returns the names of the visible Labels and RichTextLabels under `root` whose
## global transform scale is not Vector2.ONE.
static func scaled_text(root: Node) -> Array[String]:
	var names: Array[String] = []
	for text: Control in _text_nodes(root):
		if not text.get_global_transform().get_scale().is_equal_approx(Vector2.ONE):
			names.append(String(text.name))
	return names

## Returns the names of the visible Labels and RichTextLabels under `root` whose
## global rect is inside neither page.
static func escaping_text(root: Node) -> Array[String]:
	var names: Array[String] = []
	for text: Control in _text_nodes(root):
		var rect: Rect2 = text.get_global_rect()
		if not LEFT_PAGE.encloses(rect) and not RIGHT_PAGE.encloses(rect):
			names.append(String(text.name))
	return names

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

## Every Label and RichTextLabel under `root` that is visible in the tree, in
## tree order.
static func _text_nodes(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		if (child is Label or child is RichTextLabel) and (child as Control).is_visible_in_tree():
			found.append(child as Control)
		found.append_array(_text_nodes(child))
	return found
