/* Command-line support for the original NTPWEdit GUI. */
#define _CRT_SECURE_NO_WARNINGS
#define STRICT
#include <windows.h>
#include <shellapi.h>
#include <commctrl.h>
#include <wchar.h>
#include <stdio.h>
#include <stdlib.h>
#include "guiargs.h"

#define GUIARGS_PATH_CAP 4096
#define GUIARGS_USER_CAP 512

static WCHAR gui_sam_path[GUIARGS_PATH_CAP];
static WCHAR gui_user_name[GUIARGS_USER_CAP];
static int gui_rid = -1;
static int gui_auto_open = 0;
static int gui_initialized = 0;

static int gui_streqi(const WCHAR *a, const WCHAR *b)
    {
    return a && b && 0==_wcsicmp(a,b);
    }

static int gui_is_switch(const WCHAR *text)
    {
    return text && (text[0]==L'/' || text[0]==L'-');
    }

static void gui_copy(WCHAR *destination, size_t capacity, const WCHAR *source)
    {
    if(!destination || capacity==0)
        return;
    destination[0]=0;
    if(!source)
        return;
    wcsncpy(destination, source, capacity-1);
    destination[capacity-1]=0;
    }

void GuiArgsInitialize(void)
    {
    LPWSTR *argv;
    int argc=0;
    int i;
    int explicit_open=-1;

    if(gui_initialized)
        return;
    gui_initialized=1;
    gui_sam_path[0]=0;
    gui_user_name[0]=0;

    argv=CommandLineToArgvW(GetCommandLineW(), &argc);
    if(NULL==argv)
        return;

    for(i=1; i<argc; ++i)
        {
        if((gui_streqi(argv[i],L"/sam") || gui_streqi(argv[i],L"--sam")) && i+1<argc)
            {
            gui_copy(gui_sam_path, GUIARGS_PATH_CAP, argv[++i]);
            gui_auto_open=1;
            }
        else if((gui_streqi(argv[i],L"/windows") || gui_streqi(argv[i],L"--windows")) && i+1<argc)
            {
            WCHAR temp[GUIARGS_PATH_CAP];
            size_t length;
            gui_copy(temp, GUIARGS_PATH_CAP, argv[++i]);
            length=wcslen(temp);
            while(length>3 && (temp[length-1]==L'\\' || temp[length-1]==L'/'))
                temp[--length]=0;
            _snwprintf(gui_sam_path, GUIARGS_PATH_CAP-1,
                L"%s\\System32\\Config\\SAM", temp);
            gui_sam_path[GUIARGS_PATH_CAP-1]=0;
            gui_auto_open=1;
            }
        else if((gui_streqi(argv[i],L"/rid") || gui_streqi(argv[i],L"--rid")) && i+1<argc)
            {
            WCHAR *end=NULL;
            long value=wcstol(argv[++i], &end, 0);
            if(end && 0==*end && value>=0 && value<=0x7fffffffL)
                gui_rid=(int)value;
            }
        else if((gui_streqi(argv[i],L"/user") || gui_streqi(argv[i],L"--user")) && i+1<argc)
            gui_copy(gui_user_name, GUIARGS_USER_CAP, argv[++i]);
        else if(gui_streqi(argv[i],L"/open") || gui_streqi(argv[i],L"--open"))
            explicit_open=1;
        else if(gui_streqi(argv[i],L"/noopen") || gui_streqi(argv[i],L"--noopen") ||
            gui_streqi(argv[i],L"/no-open") || gui_streqi(argv[i],L"--no-open"))
            explicit_open=0;
        else if(!gui_is_switch(argv[i]) && 0==gui_sam_path[0])
            {
            gui_copy(gui_sam_path, GUIARGS_PATH_CAP, argv[i]);
            gui_auto_open=1;
            }
        }

    if(explicit_open>=0)
        gui_auto_open=explicit_open;
    LocalFree(argv);
    }

const WCHAR *GuiArgsSamPath(void)
    {
    return gui_sam_path[0] ? gui_sam_path : NULL;
    }

int GuiArgsShouldAutoOpen(void)
    {
    return gui_auto_open;
    }

int GuiArgsSelectUser(HWND list_window)
    {
    int count;
    int index;

    if(NULL==list_window || (gui_rid<0 && 0==gui_user_name[0]))
        return 0;

    count=ListView_GetItemCount(list_window);
    for(index=0; index<count; ++index)
        {
        LVITEMW item;
        WCHAR name[GUIARGS_USER_CAP];
        int match=0;

        ZeroMemory(&item, sizeof(item));
        item.mask=LVIF_PARAM;
        item.iItem=index;
        if(!SendMessageW(list_window, LVM_GETITEMW, 0, (LPARAM)&item))
            continue;

        if(gui_rid>=0 && (int)item.lParam==gui_rid)
            match=1;
        if(!match && gui_user_name[0])
            {
            LVITEMW text_item;
            name[0]=0;
            ZeroMemory(&text_item, sizeof(text_item));
            text_item.iSubItem=1;
            text_item.pszText=name;
            text_item.cchTextMax=GUIARGS_USER_CAP;
            SendMessageW(list_window, LVM_GETITEMTEXTW, (WPARAM)index, (LPARAM)&text_item);
            if(0==_wcsicmp(name, gui_user_name))
                match=1;
            }

        if(match)
            {
            ListView_SetItemState(list_window, index,
                LVIS_SELECTED|LVIS_FOCUSED,
                LVIS_SELECTED|LVIS_FOCUSED);
            ListView_EnsureVisible(list_window, index, FALSE);
            SetFocus(list_window);
            return 1;
            }
        }
    return 0;
    }
