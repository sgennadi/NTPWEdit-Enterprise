cmake_minimum_required(VERSION 3.20)

if(POLICY CMP0091)
    cmake_policy(SET CMP0091 NEW)
endif()

project(NTPWEditEnterprise VERSION 1.0.0 LANGUAGES C RC)

option(NTPWEDIT_BUILD_GUI "Build the original graphical NTPWEdit application" ON)
option(NTPWEDIT_BUILD_CLI "Build the native ntpwcli console application" ON)
option(NTPWEDIT_ENABLE_TESTS "Register native smoke tests" ON)

if(MSVC)
    # A portable WinPE binary must not require the Visual C++ redistributable.
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

add_subdirectory(libdlg)
add_subdirectory(libntpw)

set(NTPWEDIT_COMMON_INCLUDE_DIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/res"
    "${CMAKE_CURRENT_SOURCE_DIR}/libdlg"
    "${CMAKE_CURRENT_SOURCE_DIR}/libntpw"
)

if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(NTPWEDIT_ARCH "arm64")
    set(NTPWEDIT_GUI_NAME "ntpweditarm64")
    set(NTPWEDIT_RESOURCE "resource64.rc")
elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(NTPWEDIT_ARCH "amd64")
    set(NTPWEDIT_GUI_NAME "ntpwedit64")
    set(NTPWEDIT_RESOURCE "resource64.rc")
else()
    set(NTPWEDIT_ARCH "x86")
    set(NTPWEDIT_GUI_NAME "ntpwedit")
    set(NTPWEDIT_RESOURCE "resource.rc")
endif()

function(ntpwedit_apply_common_settings target_name)
    target_include_directories(${target_name} PRIVATE ${NTPWEDIT_COMMON_INCLUDE_DIRS})
    # The upstream GUI relies on the full Win32 header surface supplied by
    # windows.h. Do not enable the lean Win32 header mode here: it removes the
    # OPENFILENAME, ShellExecute and NOTIFYICON declarations used by the
    # original sources on current MSVC/Windows SDK toolchains.
    target_compile_definitions(${target_name} PRIVATE
        NTPWEDIT_ENTERPRISE_VERSION="${PROJECT_VERSION}"
        NTPWEDIT_ENTERPRISE_ARCH="${NTPWEDIT_ARCH}"
    )
    if(MSVC)
        target_compile_options(${target_name} PRIVATE /W3 /utf-8)
        target_link_options(${target_name} PRIVATE /MANIFEST:NO)
    else()
        target_compile_options(${target_name} PRIVATE -Wall -Wextra)
    endif()

    foreach(config Debug Release RelWithDebInfo MinSizeRel)
        string(TOUPPER "${config}" config_upper)
        set_target_properties(${target_name} PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY_${config_upper} "${CMAKE_BINARY_DIR}/bin/${config}"
        )
    endforeach()
endfunction()

if(NTPWEDIT_BUILD_GUI)
    add_executable(${NTPWEDIT_GUI_NAME} WIN32
        dlgabout.c
        dlghiber.c
        dlgpass.c
        guiargs.c
        main.c
        message.c
        version.c
        ${NTPWEDIT_RESOURCE}
    )
    target_link_libraries(${NTPWEDIT_GUI_NAME} PRIVATE dlglib ntpw shell32 comdlg32 comctl32 advapi32)
    ntpwedit_apply_common_settings(${NTPWEDIT_GUI_NAME})
endif()

if(NTPWEDIT_BUILD_CLI)
    # Every architecture intentionally produces the same console filename.
    # Architecture-specific artifacts keep these files in separate directories.
    add_executable(ntpwcli
        ntpwcli.c
        cli.c
    )
    target_link_libraries(ntpwcli PRIVATE ntpw)
    ntpwedit_apply_common_settings(ntpwcli)

    if(NTPWEDIT_ENABLE_TESTS AND NOT CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
        enable_testing()
        add_test(NAME ntpwcli_help COMMAND ntpwcli /?)
        add_test(NAME ntpwcli_version COMMAND ntpwcli /version)
        add_test(NAME ntpwcli_discovery_json COMMAND ntpwcli /discover /format json)
    endif()
endif()
