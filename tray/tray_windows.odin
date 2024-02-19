package tray

import "base:intrinsics"
import "base:runtime"
import "core:sys/windows"

WM_TRAY_CALLBACK_MESSAGE :: windows.WM_USER + 1
WC_TRAY_CLASS_NAME :: "TRAY"
ID_TRAY_FIRST :: 1000

wc: windows.WNDCLASSEXW
nid: windows.NOTIFYICONDATAW
hwnd: windows.HWND
hmenu: windows.HMENU
wm_taskbarcreated: windows.UINT

@(private = "file")
tray_wnd_proc :: proc "std" (
	hwnd: windows.HWND,
	msg: windows.UINT,
	wparam: windows.WPARAM,
	lparam: windows.LPARAM,
) -> windows.LRESULT {
	switch msg {
	case windows.WM_CLOSE:
		windows.DestroyWindow(hwnd)
		return 0
	case windows.WM_DESTROY:
		windows.PostQuitMessage(0)
		return 0
	case WM_TRAY_CALLBACK_MESSAGE:
		if lparam == windows.WM_LBUTTONUP || lparam == windows.WM_RBUTTONUP {
			p: windows.POINT
			windows.GetCursorPos(&p)
			windows.SetForegroundWindow(hwnd)
			cmd: windows.WORD = windows.WORD(
				windows.TrackPopupMenu(
					hmenu,
					windows.TPM_LEFTALIGN |
					windows.TPM_RIGHTBUTTON |
					windows.TPM_RETURNCMD |
					windows.TPM_NONOTIFY,
					p.x,
					p.y,
					0,
					hwnd,
					nil,
				),
			)
			windows.SendMessageW(
				hwnd,
				windows.WM_COMMAND,
				windows.WPARAM(cmd),
				0,
			)
			return 0
		}
	case windows.WM_COMMAND:
		if wparam >= ID_TRAY_FIRST {
			item: windows.MENUITEMINFOW = {
				cbSize = size_of(windows.MENUITEMINFOW),
				fMask  = windows.MIIM_ID | windows.MIIM_DATA,
			}
			if windows.GetMenuItemInfoW(
				   hmenu,
				   u32(wparam),
				   windows.FALSE,
				   &item,
			   ) {
				menu := transmute(^Tray_Menu)item.dwItemData
				if menu != nil && menu.cb != nil {
					context = runtime.default_context()
					menu.cb(menu)
				}
			}
			return 0
		}
	}

	if msg == wm_taskbarcreated {
		windows.Shell_NotifyIconW(windows.NIM_ADD, &nid)
		return 0
	}

	return windows.DefWindowProcW(hwnd, msg, wparam, lparam)
}

@(private = "file")
tray_menu :: proc(menus: []Tray_Menu, id: ^windows.UINT) -> windows.HMENU {
	popup_hmenu := windows.CreatePopupMenu()

	for menu, menu_idx in menus {
		if menu.text == "-" {
			windows.InsertMenuW(
				popup_hmenu,
				id^,
				windows.MF_SEPARATOR,
				0,
				intrinsics.constant_utf16_cstring(""),
			)
		} else {
			item: windows.MENUITEMINFOW
			item = {
				cbSize = size_of(windows.MENUITEMINFOW),
				fMask  = windows.MIIM_ID | windows.MIIM_TYPE | windows.MIIM_STATE | windows.MIIM_DATA,
				fType  = 0,
				fState = 0,
			}

			if menu.submenu != nil {
				item.fMask = item.fMask | windows.MIIM_SUBMENU
				item.hSubMenu = tray_menu(menu.submenu, id)
			}
			if menu.disabled {
				item.fState |= windows.MFS_DISABLED
			}
			if menu.checked {
				item.fState |= windows.MFS_CHECKED
			}
			item.wID = id^
			menu_text_wcstr := windows.utf8_to_wstring(
				menu.text,
				context.temp_allocator,
			)
			item.dwTypeData = menu_text_wcstr
			item.dwItemData = transmute(windows.ULONG_PTR)(&menus[menu_idx])

			windows.InsertMenuItemW(popup_hmenu, id^, windows.TRUE, &item)
		}

		id^ += 1
	}

	return popup_hmenu
}

tray_init :: proc(tray: ^Tray) -> int {
	wm_taskbarcreated = windows.RegisterWindowMessageW(
		intrinsics.constant_utf16_cstring("TaskbarCreated"),
	)

	wc = {
		cbSize        = size_of(windows.WNDCLASSEXW),
		lpfnWndProc   = tray_wnd_proc,
		hInstance     = windows.HINSTANCE(windows.GetModuleHandleW(nil)),
		lpszClassName = intrinsics.constant_utf16_cstring(WC_TRAY_CLASS_NAME),
	}
	if windows.RegisterClassExW(&wc) == 0 {
		return -1
	}

	hwnd = windows.CreateWindowExW(
		0,
		intrinsics.constant_utf16_cstring(WC_TRAY_CLASS_NAME),
		nil,
		0,
		0,
		0,
		0,
		0,
		nil,
		nil,
		nil,
		nil,
	)
	if hwnd == nil {
		return -1
	}
	windows.UpdateWindow(hwnd)

	nid = {
		cbSize           = size_of(windows.NOTIFYICONDATAW),
		hWnd             = hwnd,
		uID              = 0,
		uFlags           = windows.NIF_ICON | windows.NIF_MESSAGE,
		uCallbackMessage = WM_TRAY_CALLBACK_MESSAGE,
	}
	windows.Shell_NotifyIconW(windows.NIM_ADD, &nid)

	tray_update(tray)
	return 0
}

tray_loop :: proc(blocking: bool) -> int {
	msg: windows.MSG
	if blocking {
		windows.GetMessageW(&msg, hwnd, 0, 0)
	} else {
		windows.PeekMessageW(&msg, hwnd, 0, 0, windows.PM_REMOVE)
	}

	if msg.message == windows.WM_QUIT {
		return -1
	}

	windows.TranslateMessage(&msg)
	windows.DispatchMessageW(&msg)

	return 0
}

tray_update :: proc(tray: ^Tray) {
	prevmenu := hmenu
	id: windows.UINT = ID_TRAY_FIRST
	hmenu = tray_menu(tray.menu, &id)
	windows.SendMessageW(
		hwnd,
		windows.WM_INITMENUPOPUP,
		windows.WPARAM(hmenu),
		0,
	)

	icon: windows.HICON
	icon_wcstr := windows.utf8_to_utf16(tray.icon, context.temp_allocator)
	windows.ExtractIconExW(raw_data(icon_wcstr), 0, nil, &icon, 1)
	if nid.hIcon != nil {
		windows.DestroyIcon(nid.hIcon)
	}
	nid.hIcon = icon
	if len(tray.tooltip) > 0 {
		tooltip_wcstr := windows.utf8_to_utf16(
			tray.tooltip,
			context.temp_allocator,
		)
		copy(nid.szTip[:], tooltip_wcstr)
		nid.uFlags |= windows.NIF_TIP
	}
	windows.Shell_NotifyIconW(windows.NIM_MODIFY, &nid)

	if (prevmenu != nil) {
		windows.DestroyMenu(prevmenu)
	}
}

tray_exit :: proc() {
	windows.Shell_NotifyIconW(windows.NIM_DELETE, &nid)

	if nid.hIcon != nil {
		windows.DestroyIcon(nid.hIcon)
	}

	if hmenu != nil {
		windows.DestroyMenu(hmenu)
	}

	windows.PostQuitMessage(0)
	windows.UnregisterClassW(
		intrinsics.constant_utf16_cstring(WC_TRAY_CLASS_NAME),
		windows.HINSTANCE(windows.GetModuleHandleW(nil)),
	)
}
