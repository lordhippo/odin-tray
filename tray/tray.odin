package tray

Tray :: struct {
	icon:    string,
	tooltip: string,
	menu:    []Tray_Menu,
}

Tray_Menu :: struct {
	text:     string,
	disabled: bool,
	checked:  bool,
	checkbox: bool,
	cb:       proc (_: ^Tray_Menu),
	ctx:      rawptr,
	submenu:  []Tray_Menu,
}
