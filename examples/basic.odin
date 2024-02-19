package examples

import tray_lib "../tray"
import "core:fmt"

TRAY_ICON1 :: "icon.ico"
TRAY_ICON2 :: "icon.ico"

tray: tray_lib.Tray

main :: proc() {
	tray = {
		icon    = TRAY_ICON1,
		tooltip = "Tray",
		menu    =  {
			{text = "Hello", cb = hello_cb},
			 {
				text = "Checked",
				checked = true,
				checkbox = true,
				cb = toggle_cb,
			},
			{text = "Disabled", disabled = true},
			{text = "-"},
			 {
				text = "SubMenu",
				submenu =  {
					 {
						text = "FIRST",
						checked = true,
						checkbox = true,
						cb = submenu_cb,
					},
					 {
						text = "SECOND",
						submenu =  {
							 {
								text = "THIRD",
								submenu =  {
									{text = "7", cb = submenu_cb},
									{text = "-"},
									{text = "8", cb = submenu_cb},
								},
							},
							 {
								text = "FOUR",
								submenu =  {
									{text = "5", cb = submenu_cb},
									{text = "6", cb = submenu_cb},
								},
							},
						},
					},
				},
			},
			{text = "-"},
			{text = "Quit", cb = quit_cb},
		},
	}

	if tray_lib.tray_init(&tray) < 0 {
		fmt.eprintf("failed to create tray\n")
		return
	}

	for tray_lib.tray_loop(true) == 0 {
		fmt.printf("iteration\n")
	}
}

toggle_cb :: proc(item: ^tray_lib.Tray_Menu) {
	fmt.printf("toggle cb\n")
	item.checked = !item.checked
	tray_lib.tray_update(&tray)
}

hello_cb :: proc(item: ^tray_lib.Tray_Menu) {
	fmt.printf("hello cb\n")
	if tray.icon == TRAY_ICON1 {
		tray.icon = TRAY_ICON2
	} else {
		tray.icon = TRAY_ICON1
	}
	tray_lib.tray_update(&tray)
}

quit_cb :: proc(item: ^tray_lib.Tray_Menu) {
	fmt.printf("quit cb\n")
	tray_lib.tray_exit()
}

submenu_cb :: proc(item: ^tray_lib.Tray_Menu) {
	fmt.printf("submenu: clicked on %v\n", item.text)
	tray_lib.tray_update(&tray)
}
