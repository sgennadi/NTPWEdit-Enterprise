/* ===================================================================
 * Copyright (c) 2005-2014 Vadim Druzhin (cdslow@mail.ru).
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
 * ===================================================================
 */

#define STRICT
#include <windows.h>
#include <commctrl.h>
#include <shellapi.h>
#include <stdlib.h>
#include "dialogs.h"
#include "ctl_groupbox.h"
#include "ctl_image.h"
#include "ctl_label.h"
#include "ctl_button.h"
#include "unicode.h"
#include "version.h"
#include "dlgabout.h"

static INT_PTR URL_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam);
static INT_PTR Version_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam);
static INT_PTR Copyright_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam);
static void ExecDlgURL(HWND window, int item);
static INT_PTR NTReg_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam);

enum
    {
    ID_GRP_ABOUT=101,
    ID_GRP_ICON,
    ID_ICON,
    ID_ICON_SPACER,
    ID_GRP_VERSION,
    ID_LABEL_VERSION,
    ID_LABEL_LICENSE,
    ID_V_SPACER1,
    ID_V_SPACER2,
    ID_V_SPACER3,
    ID_LABEL_COPYRIGHT,
    ID_LABEL_MAIL,
    ID_LABEL_URL,
    ID_GRP_CREDITS,
    ID_LABEL_CREDITS_PNH,
    ID_LABEL_CREDITS_NTREG,
    ID_GRP_OK
    };

static struct DLG_Item Items[]=
    {
    {&CtlGroupBoxH, ID_GRP_ABOUT, NULL, 0, 0, NULL},
    {&CtlGroupH, ID_GRP_ICON, GRP_TITLE_FILL, 0, ID_GRP_ABOUT, NULL},
    {&CtlIcon, ID_ICON, L"IconApp", 0, ID_GRP_ICON, NULL},
    {&CtlGroupBoxSpacer, ID_ICON_SPACER, NULL, 0, ID_GRP_ABOUT, NULL},
    {&CtlGroupV, ID_GRP_VERSION, NULL, 0, ID_GRP_ABOUT, NULL},
    {&CtlLabel, ID_LABEL_VERSION, NULL, 0, ID_GRP_VERSION, Version_Proc},
    {&CtlLabel, ID_LABEL_LICENSE, L"GPL", 0, ID_GRP_VERSION, NULL},
    {&CtlLabel, ID_V_SPACER1, L" ", 0, ID_GRP_VERSION, NULL},
    {&CtlLabel, ID_LABEL_COPYRIGHT, NULL, 0, ID_GRP_VERSION, Copyright_Proc},
    {&CtlLabel, ID_V_SPACER2, L" ", 0, ID_GRP_VERSION, NULL},
    {&CtlLabel, ID_LABEL_MAIL, L"https://github.com/sgennadi/NTPWEdit-Enterprise", 0, ID_GRP_VERSION, URL_Proc},
    {&CtlLabel, ID_LABEL_URL, L"Third-party notices: LICENSE-ENTERPRISE-NOTICE.txt", 0, ID_GRP_VERSION, NULL},
    {&CtlGroupBoxV, ID_GRP_CREDITS, NULL, 0, 0, NULL},
    {&CtlLabel, ID_LABEL_CREDITS_PNH,
        L"\nNTPWEdit Enterprise is based on GPL-licensed upstream code.\n"
        L"Original and third-party notices are preserved in the source\n"
        L"files and LICENSE-ENTERPRISE-NOTICE.txt.\n",
        0, ID_GRP_CREDITS, NULL},
    {&CtlLabel, ID_LABEL_CREDITS_NTREG, L"", 0, ID_GRP_CREDITS, NULL},
    {&CtlLabel, ID_V_SPACER3, L" ", 0, ID_GRP_CREDITS, NULL},
    {&CtlGroupBoxH, ID_GRP_OK, NULL, 0, 0, NULL},
    {&CtlDefButton, IDOK, L"OK", 0, ID_GRP_OK, NULL},
    };

static INT_PTR URL_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam)
    {
    (void)lParam; /* Unused */

    if(WM_COMMAND==msg)
        {
        if(HIWORD(wParam)==STN_CLICKED)
            {
            ExecDlgURL(window, id);
            return TRUE;
            }
        }
    else if(WM_CTLCOLORSTATIC==msg)
        {
        SetTextColor((HDC)wParam, RGB(0, 0, 255));
        SetBkColor((HDC)wParam, GetSysColor(COLOR_3DFACE));
        return (INT_PTR)GetSysColorBrush(COLOR_3DFACE);
        }
    
    return FALSE;
    }

static INT_PTR Version_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam)
    {
    (void)wParam; /* Unused */
    (void)lParam; /* Unused */

    if(WM_INITDIALOG==msg)
        {
        SetDlgItemTextU(window, id, AppTitle);
        return TRUE;
        }
    
    return FALSE;
    }

static INT_PTR Copyright_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam)
    {
    (void)wParam; /* Unused */
    (void)lParam; /* Unused */

    if(WM_INITDIALOG==msg)
        {
        SetDlgItemTextU(window, id, AppAuthor);
        return TRUE;
        }
    
    return FALSE;
    }

static INT_PTR NTReg_Proc(
    HWND window, WORD id, UINT msg, WPARAM wParam, LPARAM lParam)
    {
    extern char ntreg_version[];

    (void)wParam; /* Unused */
    (void)lParam; /* Unused */

    if(WM_INITDIALOG==msg)
        {
        SetDlgItemText(window, id, ntreg_version);
        return TRUE;
        }
    
    return FALSE;
    }

void AboutDialog(HWND window)
    {
    DlgRunU(
        window,
        L"About NTPWEdit Enterprise",
        0,
        WS_BORDER|WS_CAPTION|WS_SYSMENU,
        0,
        Items,
        sizeof(Items)/sizeof(*Items),
        NULL
        );
    }

static void ExecDlgURL(HWND window, int item)
    {
    char buf[256];
    
    GetDlgItemText(window, item, buf, sizeof(buf));
    ShellExecute(NULL, "open", buf, NULL, NULL, 0);
    }
