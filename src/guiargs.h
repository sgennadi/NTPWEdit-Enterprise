#ifndef NTPWEDIT_ENTERPRISE_GUIARGS_H
#define NTPWEDIT_ENTERPRISE_GUIARGS_H

#include <windows.h>

void GuiArgsInitialize(void);
const WCHAR *GuiArgsSamPath(void);
int GuiArgsShouldAutoOpen(void);
int GuiArgsSelectUser(HWND list_window);

#endif
