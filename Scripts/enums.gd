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
	ADD_ELEMENT,
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

## Corresponds to the priority types that can be assigned to an ElementLabel
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
}
