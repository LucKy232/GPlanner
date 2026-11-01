class_name Enums
## Contains all of the enums to be accessed globally.

## Corresponds to the app mode state saved in PlannerCanvas's SettingsStates, read by main.gd
enum AppMode {
	PLANNING,
	DRAWING,
}

## Corresponds to the PlannerToolBox's Items from main_scene
enum Tool {
	SELECT,
	ADD_TEXT_ELEMENT,
	ADD_LIST,
	REMOVE_ELEMENT,
	ELEMENT_STYLE_SETTINGS,
	ADD_CONNECTION,
	REMOVE_CONNECTIONS,
	MARK_COMPLETED,
}

## Corresponds to the SaveState of the PlannerCanvas, requests an action to be done after saving images in main.gd
enum RequestedActionType {
	NEW_BUTTON,
	LOAD_BUTTON,
	CLOSE_TAB_BUTTON,
	CONFIRMATION_TAB,
}

## Corresponds to the priority types that can be assigned to a TextElement
enum Priority {
	ACTIVE,
	HIGH,
	MEDIUM,
	LOW,
	NONE,
}

## Corresponds to the checkboxes that the user can change in the SettingsDrawer
## and get set in PlannerCanvas's SettingsStates
enum Checkbox {
	SHOW_PRIORITIES,
	SHOW_PRIORITY_TOOL,
	SHOW_COMPLETED,
}

## Corresponds to the DrawingToolBox's Items, used in DrawingSettings class
enum DrawingTool {
	PENCIL,
	BRUSH,
	ERASER_PENCIL,
	ERASER_BRUSH,
	MOVE,
	#BOX_SELECT,
}

enum Side {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM,
}

## Corresponds to each setting in StyleSettings
enum StyleSetting {
	BG_COLOR,
	BORDER_SIZE,
	BORDER_COLOR,
	BORDER_BLEND,
	FONT_SIZE,
	FONT_COLOR,
	OUTLINE_SIZE,
	OUTLINE_COLOR,
	LINE_SPACING,
	TITLE_FONT_SIZE,
	TITLE_FONT_COLOR,
	TITLE_OUTLINE_SIZE,
	TITLE_OUTLINE_COLOR,
	TITLE_LINE_SPACING,
	ENTRY_SEPARATION,
	ENTRY_DIV_ENABLED,
	ENTRY_DIV_COLOR,
}

const style_setting_names: Dictionary[StyleSetting, String] = {
	StyleSetting.BG_COLOR: "Background Color",
	StyleSetting.BORDER_SIZE: "Border Size",
	StyleSetting.BORDER_COLOR: "Border Color",
	StyleSetting.BORDER_BLEND: "Border Blend",
	StyleSetting.FONT_SIZE: "Font Size",
	StyleSetting.FONT_COLOR: "Font Color",
	StyleSetting.OUTLINE_SIZE: "Outline Size",
	StyleSetting.OUTLINE_COLOR: "Outline Color",
	StyleSetting.LINE_SPACING: "Line Spacing",
	StyleSetting.TITLE_FONT_SIZE: "Title Font Size",
	StyleSetting.TITLE_FONT_COLOR: "Title Font Color",
	StyleSetting.TITLE_OUTLINE_SIZE: "Title Outline Size",
	StyleSetting.TITLE_OUTLINE_COLOR: "Title Outline Color",
	StyleSetting.TITLE_LINE_SPACING: "Title Line Spacing",
	StyleSetting.ENTRY_SEPARATION: "List Entry Separation",
	StyleSetting.ENTRY_DIV_ENABLED: "List Separator Toggle",
	StyleSetting.ENTRY_DIV_COLOR: "List Separator Color",
}
