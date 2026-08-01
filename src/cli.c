/*
 * NTPWEdit Enterprise CLI 1.0.0
 *
 * A native console front-end for the upstream NTPWEdit offline SAM library.
 * It operates only on an explicitly supplied or automatically discovered
 * offline SAM hive. Mutation commands require an explicit confirmation token.
 */
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <direct.h>
#include <ctype.h>
#include <time.h>
#include "ntpw.h"
#include "cli.h"

#define CLI_MAX_USERS 4096
#define CLI_MAX_NAME 512
#define CLI_MAX_DISCOVERED 26
#define CLI_MAX_PATH 4096
#define CLI_PASSWORD_MAX 16

#define EXIT_OK 0
#define EXIT_USAGE 1
#define EXIT_IO 2
#define EXIT_CONFIRM 3
#define EXIT_USER_NOT_FOUND 4
#define EXIT_CANCELLED 5
#define EXIT_MUTATION 6
#define EXIT_WRITE 7
#define EXIT_AMBIGUOUS 8
#define EXIT_VALIDATION 9

typedef struct cli_user {
    int rid;
    char name[CLI_MAX_NAME];
    struct account_status status;
} CLI_USER;

typedef struct cli_installation {
    char drive[4];
    char windows_path[CLI_MAX_PATH];
    char sam_path[CLI_MAX_PATH];
    UINT drive_type;
} CLI_INSTALLATION;

typedef enum cli_format {
    FORMAT_TEXT = 0,
    FORMAT_JSON = 1
} CLI_FORMAT;

typedef struct cli_options {
    const char *sam;
    const char *windows_path;
    const char *user_name;
    const char *rid_text;
    const char *output_path;
    const char *backup_dir;
    const char *restore_dir;
    const char *confirm;
    const char *password_file;
    int auto_discover;
    int select_index;
    int action_discover;
    int action_list;
    int action_status;
    int action_backup;
    int action_restore;
    int action_unlock;
    int action_enable;
    int action_disable;
    int action_unlock_enable;
    int action_password_prompt;
    int action_password_stdin;
    int action_password_file;
    int action_password_blank;
    int show_help;
    int show_version;
    int quiet;
    CLI_FORMAT format;
} CLI_OPTIONS;

static int streqi(const char *a, const char *b)
{
    return a && b && _stricmp(a, b) == 0;
}

static int is_switch(const char *s)
{
    return s && (s[0] == '/' || s[0] == '-');
}

static const char *next_value(int argc, char **argv, int *index, const char *name)
{
    if (*index + 1 >= argc) {
        fprintf(stderr, "Missing value for %s.\n", name);
        return NULL;
    }
    ++(*index);
    return argv[*index];
}

static int parse_positive_int(const char *text, int *value)
{
    char *end = NULL;
    long parsed;
    if (!text || !*text) return 0;
    parsed = strtol(text, &end, 0);
    if (!end || *end || parsed < 0 || parsed > 0x7fffffffL) return 0;
    *value = (int)parsed;
    return 1;
}

static const char *drive_type_text(UINT type)
{
    switch (type) {
        case DRIVE_FIXED: return "fixed";
        case DRIVE_REMOVABLE: return "removable";
        case DRIVE_REMOTE: return "remote";
        case DRIVE_CDROM: return "cdrom";
        case DRIVE_RAMDISK: return "ramdisk";
        case DRIVE_NO_ROOT_DIR: return "no_root";
        default: return "unknown";
    }
}

static void json_escape(FILE *f, const char *s)
{
    const unsigned char *p = (const unsigned char *)(s ? s : "");
    for (; *p; ++p) {
        switch (*p) {
            case '"': fputs("\\\"", f); break;
            case '\\': fputs("\\\\", f); break;
            case '\b': fputs("\\b", f); break;
            case '\f': fputs("\\f", f); break;
            case '\n': fputs("\\n", f); break;
            case '\r': fputs("\\r", f); break;
            case '\t': fputs("\\t", f); break;
            default:
                if (*p < 0x20) fprintf(f, "\\u%04x", (unsigned int)*p);
                else fputc(*p, f);
        }
    }
}

static FILE *open_output(const char *path, int *must_close)
{
    FILE *f;
    *must_close = 0;
    if (!path || !strcmp(path, "-")) return stdout;
    f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "Cannot open output file: %s\n", path);
        return NULL;
    }
    *must_close = 1;
    return f;
}

static void print_banner(FILE *f)
{
    fprintf(f, "NTPWEdit Enterprise CLI %s\n", NTPWCLI_VERSION);
}

static void print_usage(void)
{
    print_banner(stdout);
    puts(
        "\nUSAGE\n"
        "  ntpwcli.exe /discover [/format text|json] [/output FILE]\n"
        "  ntpwcli.exe (/sam PATH | /windows PATH | /auto [/select N]) /list\n"
        "  ntpwcli.exe (...) /json [FILE]\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /status [/format json]\n"
        "  ntpwcli.exe (...) /backup DIR\n"
        "  ntpwcli.exe (...) /restore DIR --confirm RESTORE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /unlock --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /enable --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /disable --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /unlock-enable --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /password-prompt --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /password-stdin --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /password-file FILE --confirm WRITE\n"
        "  ntpwcli.exe (...) (/user NAME | /rid RID) /password-blank --confirm WRITE\n"
        "\nSOURCE SELECTION\n"
        "  /sam PATH          Offline SAM hive path.\n"
        "  /windows PATH      Offline Windows directory; SAM path is inferred.\n"
        "  /auto              Search drive letters for Windows\\System32\\Config\\SAM.\n"
        "  /select N          Select discovery result N when multiple installations exist.\n"
        "\nOUTPUT\n"
        "  /format text|json  Select output format.\n"
        "  /json [FILE]       JSON shortcut; FILE is optional, '-' means stdout.\n"
        "  /output FILE       Write text or JSON output to FILE.\n"
        "  /quiet             Suppress informational messages.\n"
        "\nPASSWORD INPUT\n"
        "  /password-prompt   Hidden interactive input, recommended.\n"
        "  /password-stdin    Read one line from standard input.\n"
        "  /password-file     Read one line from a protected temporary file.\n"
        "\nEXIT CODES\n"
        "  0 success; 1 usage; 2 I/O; 3 confirmation; 4 user not found;\n"
        "  5 cancelled; 6 mutation failed; 7 hive write failed; 8 ambiguous; 9 validation.\n"
        "\nThe tool changes local offline SAM accounts only. It does not change domain,\n"
        "Active Directory, Entra ID, Microsoft account, or Windows Hello credentials."
    );
}

static int parse_options(int argc, char **argv, CLI_OPTIONS *o)
{
    int i;
    memset(o, 0, sizeof(*o));
    o->select_index = 0;
    o->format = FORMAT_TEXT;

    for (i = 1; i < argc; ++i) {
        const char *a = argv[i];
        if (streqi(a, "/?") || streqi(a, "-h") || streqi(a, "--help")) o->show_help = 1;
        else if (streqi(a, "/version") || streqi(a, "--version")) o->show_version = 1;
        else if (streqi(a, "/sam") || streqi(a, "--sam")) { o->sam = next_value(argc, argv, &i, a); if (!o->sam) return 0; }
        else if (streqi(a, "/windows") || streqi(a, "--windows")) { o->windows_path = next_value(argc, argv, &i, a); if (!o->windows_path) return 0; }
        else if (streqi(a, "/auto") || streqi(a, "--auto")) o->auto_discover = 1;
        else if (streqi(a, "/select") || streqi(a, "--select")) {
            const char *v = next_value(argc, argv, &i, a);
            if (!v || !parse_positive_int(v, &o->select_index) || o->select_index < 1) { fprintf(stderr, "Invalid /select value.\n"); return 0; }
        }
        else if (streqi(a, "/user") || streqi(a, "--user")) { o->user_name = next_value(argc, argv, &i, a); if (!o->user_name) return 0; }
        else if (streqi(a, "/rid") || streqi(a, "--rid")) { o->rid_text = next_value(argc, argv, &i, a); if (!o->rid_text) return 0; }
        else if (streqi(a, "/discover") || streqi(a, "--discover")) o->action_discover = 1;
        else if (streqi(a, "/list") || streqi(a, "--list")) o->action_list = 1;
        else if (streqi(a, "/status") || streqi(a, "--status")) o->action_status = 1;
        else if (streqi(a, "/backup") || streqi(a, "--backup")) { o->action_backup = 1; o->backup_dir = next_value(argc, argv, &i, a); if (!o->backup_dir) return 0; }
        else if (streqi(a, "/restore") || streqi(a, "--restore")) { o->action_restore = 1; o->restore_dir = next_value(argc, argv, &i, a); if (!o->restore_dir) return 0; }
        else if (streqi(a, "/unlock") || streqi(a, "--unlock")) o->action_unlock = 1;
        else if (streqi(a, "/enable") || streqi(a, "--enable")) o->action_enable = 1;
        else if (streqi(a, "/disable") || streqi(a, "--disable")) o->action_disable = 1;
        else if (streqi(a, "/unlock-enable") || streqi(a, "--unlock-enable")) o->action_unlock_enable = 1;
        else if (streqi(a, "/password-prompt") || streqi(a, "--password-prompt")) o->action_password_prompt = 1;
        else if (streqi(a, "/password-stdin") || streqi(a, "--password-stdin")) o->action_password_stdin = 1;
        else if (streqi(a, "/password-file") || streqi(a, "--password-file")) { o->action_password_file = 1; o->password_file = next_value(argc, argv, &i, a); if (!o->password_file) return 0; }
        else if (streqi(a, "/password-blank") || streqi(a, "--password-blank")) o->action_password_blank = 1;
        else if (streqi(a, "/confirm") || streqi(a, "--confirm")) { o->confirm = next_value(argc, argv, &i, a); if (!o->confirm) return 0; }
        else if (streqi(a, "/format") || streqi(a, "--format")) {
            const char *v = next_value(argc, argv, &i, a);
            if (!v) return 0;
            if (streqi(v, "json")) o->format = FORMAT_JSON;
            else if (streqi(v, "text")) o->format = FORMAT_TEXT;
            else { fprintf(stderr, "Invalid output format: %s\n", v); return 0; }
        }
        else if (streqi(a, "/json") || streqi(a, "--json")) {
            o->format = FORMAT_JSON;
            o->action_list = 1;
            if (i + 1 < argc && !is_switch(argv[i + 1])) o->output_path = argv[++i];
        }
        else if (streqi(a, "/output") || streqi(a, "--output")) { o->output_path = next_value(argc, argv, &i, a); if (!o->output_path) return 0; }
        else if (streqi(a, "/quiet") || streqi(a, "--quiet")) o->quiet = 1;
        else {
            fprintf(stderr, "Unknown argument: %s\n", a);
            return 0;
        }
    }
    return 1;
}

static int file_exists(const char *path)
{
    DWORD attr = GetFileAttributesA(path);
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

static void trim_trailing_slashes(char *path)
{
    size_t n;
    if (!path) return;
    n = strlen(path);
    while (n > 3 && (path[n - 1] == '\\' || path[n - 1] == '/')) path[--n] = 0;
}

static int discover_installations(CLI_INSTALLATION *items, int max_items)
{
    DWORD mask = GetLogicalDrives();
    int count = 0;
    int letter;
    for (letter = 0; letter < 26 && count < max_items; ++letter) {
        char root[4];
        char windows_path[CLI_MAX_PATH];
        char sam_path[CLI_MAX_PATH];
        if (!(mask & (1u << letter))) continue;
        if ((char)('A' + letter) == 'X') continue; /* WinPE RAM drive */
        root[0] = (char)('A' + letter); root[1] = ':'; root[2] = '\\'; root[3] = 0;
        snprintf(windows_path, sizeof(windows_path), "%c:\\Windows", 'A' + letter);
        snprintf(sam_path, sizeof(sam_path), "%s\\System32\\Config\\SAM", windows_path);
        if (!file_exists(sam_path)) continue;
        snprintf(items[count].drive, sizeof(items[count].drive), "%c:", 'A' + letter);
        strncpy(items[count].windows_path, windows_path, sizeof(items[count].windows_path) - 1);
        items[count].windows_path[sizeof(items[count].windows_path) - 1] = 0;
        strncpy(items[count].sam_path, sam_path, sizeof(items[count].sam_path) - 1);
        items[count].sam_path[sizeof(items[count].sam_path) - 1] = 0;
        items[count].drive_type = GetDriveTypeA(root);
        ++count;
    }
    return count;
}

static int emit_discovery(const CLI_INSTALLATION *items, int count, CLI_FORMAT format, const char *output)
{
    int i, close_file = 0;
    FILE *f = open_output(output, &close_file);
    if (!f) return EXIT_IO;
    if (format == FORMAT_JSON) {
        fprintf(f, "{\n  \"schemaVersion\": 1,\n  \"tool\": \"ntpwcli\",\n  \"version\": \"%s\",\n  \"installations\": [\n", NTPWCLI_VERSION);
        for (i = 0; i < count; ++i) {
            fprintf(f, "    {\"index\": %d, \"drive\": \"", i + 1); json_escape(f, items[i].drive);
            fprintf(f, "\", \"driveType\": \"%s\", \"windowsPath\": \"", drive_type_text(items[i].drive_type)); json_escape(f, items[i].windows_path);
            fprintf(f, "\", \"samPath\": \""); json_escape(f, items[i].sam_path);
            fprintf(f, "\"}%s\n", i + 1 == count ? "" : ",");
        }
        fprintf(f, "  ]\n}\n");
    } else {
        fprintf(f, "INDEX\tDRIVE\tTYPE\tWINDOWS\tSAM\n");
        for (i = 0; i < count; ++i)
            fprintf(f, "%d\t%s\t%s\t%s\t%s\n", i + 1, items[i].drive, drive_type_text(items[i].drive_type), items[i].windows_path, items[i].sam_path);
    }
    if (close_file) fclose(f);
    return EXIT_OK;
}

static int resolve_sam_path(const CLI_OPTIONS *o, char *sam_path, size_t capacity)
{
    CLI_INSTALLATION items[CLI_MAX_DISCOVERED];
    int count;
    if (o->sam) {
        strncpy(sam_path, o->sam, capacity - 1); sam_path[capacity - 1] = 0;
        return file_exists(sam_path) ? EXIT_OK : EXIT_IO;
    }
    if (o->windows_path) {
        char temp[CLI_MAX_PATH];
        strncpy(temp, o->windows_path, sizeof(temp) - 1); temp[sizeof(temp) - 1] = 0;
        trim_trailing_slashes(temp);
        snprintf(sam_path, capacity, "%s\\System32\\Config\\SAM", temp);
        return file_exists(sam_path) ? EXIT_OK : EXIT_IO;
    }
    if (!o->auto_discover) return EXIT_USAGE;
    count = discover_installations(items, CLI_MAX_DISCOVERED);
    if (count == 0) return EXIT_IO;
    if (o->select_index > 0) {
        if (o->select_index > count) return EXIT_VALIDATION;
        strncpy(sam_path, items[o->select_index - 1].sam_path, capacity - 1); sam_path[capacity - 1] = 0;
        return EXIT_OK;
    }
    if (count > 1) {
        fprintf(stderr, "Multiple Windows installations were found. Use /select N or /sam PATH.\n");
        emit_discovery(items, count, FORMAT_TEXT, NULL);
        return EXIT_AMBIGUOUS;
    }
    strncpy(sam_path, items[0].sam_path, capacity - 1); sam_path[capacity - 1] = 0;
    return EXIT_OK;
}

static void utf16_name_to_utf8(const char *source, char *destination, int capacity)
{
    const WCHAR *wide = (const WCHAR *)source;
    if (!WideCharToMultiByte(CP_UTF8, 0, wide, -1, destination, capacity, NULL, NULL))
        strcpy(destination, "<name-conversion-failed>");
}

static int load_users(const char *sam, CLI_USER *users, int maximum)
{
    char *hives[H_COUNT] = { 0 };
    struct search_user search;
    struct user_info *info;
    int count = 0;
    hives[H_SAM] = (char *)sam;
    if (open_hives(hives) == 0) return -1;
    info = first_user(&search);
    while (info && count < maximum) {
        memset(&users[count], 0, sizeof(users[count]));
        users[count].rid = info->rid;
        utf16_name_to_utf8(info->unicode_name, users[count].name, CLI_MAX_NAME);
        if (!get_account_status(info->rid, &users[count].status)) {
            free(info);
            close_hives();
            return -2;
        }
        free(info);
        ++count;
        info = next_user(&search);
    }
    if (info) free(info);
    return count;
}

static CLI_USER *find_user(CLI_USER *users, int count, const char *name, const char *rid_text)
{
    int i, rid;
    if (rid_text) {
        if (!parse_positive_int(rid_text, &rid)) return NULL;
        for (i = 0; i < count; ++i) if (users[i].rid == rid) return &users[i];
    }
    if (name) for (i = 0; i < count; ++i) if (!_stricmp(users[i].name, name)) return &users[i];
    return NULL;
}

static const char *account_state(const struct account_status *s)
{
    if (s->disabled && s->locked) return "disabled_and_locked";
    if (s->disabled) return "disabled";
    if (s->locked) return "locked";
    return "enabled";
}

static void emit_user_json(FILE *f, const CLI_USER *u)
{
    fprintf(f, "{\"name\": \""); json_escape(f, u->name);
    fprintf(f, "\", \"rid\": %d, \"ridHex\": \"0x%08X\", \"state\": \"%s\", ", u->rid, (unsigned int)u->rid, account_state(&u->status));
    fprintf(f, "\"disabled\": %s, \"locked\": %s, \"autoLocked\": %s, \"lockedByFailedCount\": %s, ",
        u->status.disabled ? "true" : "false", u->status.locked ? "true" : "false",
        u->status.auto_locked ? "true" : "false", u->status.locked_by_count ? "true" : "false");
    fprintf(f, "\"failedCount\": %u, \"loginCount\": %u, \"lockoutThreshold\": %d, ",
        (unsigned int)u->status.failed_count, (unsigned int)u->status.login_count, u->status.lockout_threshold);
    fprintf(f, "\"passwordNeverExpires\": %s, \"passwordNotRequired\": %s, \"normalAccount\": %s, \"acbBits\": %u}",
        u->status.password_never_expires ? "true" : "false", u->status.password_not_required ? "true" : "false",
        u->status.normal_account ? "true" : "false", (unsigned int)u->status.acb_bits);
}

static int emit_users(CLI_USER *users, int count, const char *sam, CLI_FORMAT format, const char *output, int selected_index)
{
    int i, close_file = 0;
    FILE *f = open_output(output, &close_file);
    if (!f) return EXIT_IO;
    if (format == FORMAT_JSON) {
        fprintf(f, "{\n  \"schemaVersion\": 1,\n  \"tool\": \"ntpwcli\",\n  \"version\": \"%s\",\n  \"samPath\": \"", NTPWCLI_VERSION);
        json_escape(f, sam);
        fprintf(f, "\",\n  \"readOnly\": %s,\n  \"users\": [\n", is_hives_ro() ? "true" : "false");
        for (i = 0; i < count; ++i) {
            fputs("    ", f); emit_user_json(f, &users[i]);
            fprintf(f, "%s\n", i + 1 == count ? "" : ",");
        }
        fprintf(f, "  ]");
        if (selected_index >= 0 && selected_index < count) {
            fprintf(f, ",\n  \"selectedUser\": "); emit_user_json(f, &users[selected_index]);
        }
        fprintf(f, "\n}\n");
    } else if (selected_index >= 0 && selected_index < count) {
        const CLI_USER *u = &users[selected_index];
        fprintf(f, "Name                  : %s\n", u->name);
        fprintf(f, "RID                   : %d (0x%08X)\n", u->rid, (unsigned int)u->rid);
        fprintf(f, "State                 : %s\n", account_state(&u->status));
        fprintf(f, "Disabled              : %s\n", u->status.disabled ? "Yes" : "No");
        fprintf(f, "Locked                : %s\n", u->status.locked ? "Yes" : "No");
        fprintf(f, "Automatic lock flag   : %s\n", u->status.auto_locked ? "Yes" : "No");
        fprintf(f, "Failed login count    : %u\n", (unsigned int)u->status.failed_count);
        fprintf(f, "Lockout threshold     : %d\n", u->status.lockout_threshold);
        fprintf(f, "Total login count     : %u\n", (unsigned int)u->status.login_count);
        fprintf(f, "Password never expires: %s\n", u->status.password_never_expires ? "Yes" : "No");
        fprintf(f, "Password not required : %s\n", u->status.password_not_required ? "Yes" : "No");
    } else {
        fprintf(f, "RID\tSTATE\tDISABLED\tLOCKED\tFAILED\tLOGINS\tPWD_NO_EXP\tNAME\n");
        for (i = 0; i < count; ++i) {
            fprintf(f, "%d\t%s\t%s\t%s\t%u\t%u\t%s\t%s\n", users[i].rid, account_state(&users[i].status),
                users[i].status.disabled ? "yes" : "no", users[i].status.locked ? "yes" : "no",
                (unsigned int)users[i].status.failed_count, (unsigned int)users[i].status.login_count,
                users[i].status.password_never_expires ? "yes" : "no", users[i].name);
        }
    }
    if (close_file) fclose(f);
    return EXIT_OK;
}

static int make_directory_recursive(const char *path)
{
    char temp[CLI_MAX_PATH];
    char *p;
    size_t len;
    if (!path || !*path) return 0;
    strncpy(temp, path, sizeof(temp) - 1); temp[sizeof(temp) - 1] = 0;
    trim_trailing_slashes(temp);
    len = strlen(temp);
    if (len == 0) return 0;
    for (p = temp + 1; *p; ++p) {
        if (*p == '\\' || *p == '/') {
            char saved = *p;
            *p = 0;
            if (!(strlen(temp) == 2 && temp[1] == ':')) CreateDirectoryA(temp, NULL);
            *p = saved;
        }
    }
    if (CreateDirectoryA(temp, NULL)) return 1;
    return GetLastError() == ERROR_ALREADY_EXISTS;
}

static void config_directory_from_sam(const char *sam, char *directory, size_t capacity)
{
    char *slash;
    strncpy(directory, sam, capacity - 1); directory[capacity - 1] = 0;
    slash = strrchr(directory, '\\');
    if (!slash) slash = strrchr(directory, '/');
    if (slash) *slash = 0;
}

static int copy_if_present(const char *source, const char *destination, int required)
{
    if (!file_exists(source)) return required ? 0 : 1;
    if (!CopyFileA(source, destination, FALSE)) return 0;
    return 1;
}

static int backup_hive_set(const char *sam, const char *destination)
{
    static const char *names[] = { "SAM", "SYSTEM", "SECURITY", "DEFAULT", "SOFTWARE" };
    static const char *suffixes[] = { "", ".LOG1", ".LOG2" };
    char source_dir[CLI_MAX_PATH], source[CLI_MAX_PATH], target[CLI_MAX_PATH], manifest[CLI_MAX_PATH];
    FILE *f;
    int i, j;
    config_directory_from_sam(sam, source_dir, sizeof(source_dir));
    if (!make_directory_recursive(destination)) {
        fprintf(stderr, "Cannot create backup directory: %s\n", destination);
        return EXIT_IO;
    }
    for (i = 0; i < (int)(sizeof(names) / sizeof(names[0])); ++i) {
        for (j = 0; j < (int)(sizeof(suffixes) / sizeof(suffixes[0])); ++j) {
            snprintf(source, sizeof(source), "%s\\%s%s", source_dir, names[i], suffixes[j]);
            snprintf(target, sizeof(target), "%s\\%s%s", destination, names[i], suffixes[j]);
            if (!copy_if_present(source, target, i == 0 && j == 0)) {
                fprintf(stderr, "Backup copy failed: %s -> %s\n", source, target);
                return EXIT_IO;
            }
        }
    }
    snprintf(manifest, sizeof(manifest), "%s\\backup-info.json", destination);
    f = fopen(manifest, "wb");
    if (f) {
        fprintf(f, "{\n  \"schemaVersion\": 1,\n  \"tool\": \"ntpwcli\",\n  \"version\": \"%s\",\n  \"sourceSam\": \"", NTPWCLI_VERSION);
        json_escape(f, sam);
        fprintf(f, "\"\n}\n");
        fclose(f);
    }
    return EXIT_OK;
}

static int restore_hive_set(const char *sam, const char *source_directory)
{
    static const char *names[] = { "SAM", "SYSTEM", "SECURITY", "DEFAULT", "SOFTWARE" };
    static const char *suffixes[] = { "", ".LOG1", ".LOG2" };
    char target_dir[CLI_MAX_PATH], source[CLI_MAX_PATH], target[CLI_MAX_PATH];
    int i, j;

    snprintf(source, sizeof(source), "%s\\SAM", source_directory);
    if (!file_exists(source)) {
        fprintf(stderr, "Restore source does not contain a SAM hive: %s\n", source);
        return EXIT_IO;
    }

    config_directory_from_sam(sam, target_dir, sizeof(target_dir));
    for (i = 0; i < (int)(sizeof(names) / sizeof(names[0])); ++i) {
        for (j = 0; j < (int)(sizeof(suffixes) / sizeof(suffixes[0])); ++j) {
            snprintf(source, sizeof(source), "%s\\%s%s", source_directory, names[i], suffixes[j]);
            if (!file_exists(source)) continue;
            snprintf(target, sizeof(target), "%s\\%s%s", target_dir, names[i], suffixes[j]);
            if (!CopyFileA(source, target, FALSE)) {
                fprintf(stderr, "Restore copy failed: %s -> %s\n", source, target);
                return EXIT_IO;
            }
        }
    }
    return EXIT_OK;
}

static int emit_hive_operation_result(const CLI_OPTIONS *o, const char *sam, const char *operation, const char *path)
{
    int close_file = 0;
    FILE *f = open_output(o->output_path, &close_file);
    if (!f) return EXIT_IO;
    if (o->format == FORMAT_JSON) {
        fprintf(f, "{\"schemaVersion\": 1, \"tool\": \"ntpwcli\", \"version\": \"%s\", \"success\": true, \"operation\": \"", NTPWCLI_VERSION);
        json_escape(f, operation);
        fprintf(f, "\", \"samPath\": \"");
        json_escape(f, sam);
        fprintf(f, "\", \"path\": \"");
        json_escape(f, path);
        fprintf(f, "\"}\n");
    } else if (!o->quiet) {
        fprintf(f, "%s completed: %s\n", operation, path);
    }
    if (close_file) fclose(f);
    return EXIT_OK;
}

static int read_password_hidden(char *buffer, int capacity)
{
    int c, length = 0, overflow = 0;
    fprintf(stderr, "New password (maximum %d characters; input hidden): ", CLI_PASSWORD_MAX);
    for (;;) {
        c = _getch();
        if (c == 3 || c == 27) { fputs("\n", stderr); return 0; }
        if (c == '\r' || c == '\n') break;
        if (c == '\b') {
            if (overflow > 0) { --overflow; fputs("\b \b", stderr); }
            else if (length > 0) { --length; fputs("\b \b", stderr); }
            continue;
        }
        if (c >= 32) {
            if (length < capacity - 1 && length < CLI_PASSWORD_MAX && overflow == 0)
                buffer[length++] = (char)c;
            else
                ++overflow;
            fputc('*', stderr);
        }
    }
    buffer[length] = 0;
    fputc('\n', stderr);
    if (overflow > 0) {
        SecureZeroMemory(buffer, (size_t)capacity);
        fprintf(stderr, "Password is longer than %d characters. Nothing was changed.\n", CLI_PASSWORD_MAX);
        return -1;
    }
    return 1;
}

static int read_password_line(FILE *f, char *buffer, int capacity)
{
    char line[512];
    size_t len;
    if (!fgets(line, sizeof(line), f)) return 0;
    len = strcspn(line, "\r\n");
    if (len > CLI_PASSWORD_MAX || len >= (size_t)capacity) {
        SecureZeroMemory(line, sizeof(line));
        return 0;
    }
    memcpy(buffer, line, len);
    buffer[len] = 0;
    SecureZeroMemory(line, sizeof(line));
    return 1;
}

static int read_password_file(const char *path, char *buffer, int capacity)
{
    FILE *f;
    int result;
    if (!path || !*path) return -1;
    f = fopen(path, "rb");
    if (!f) return -1;
    result = read_password_line(f, buffer, capacity);
    fclose(f);
    return result;
}

static void append_operation(char *buffer, size_t capacity, const char *operation)
{
    size_t used;
    if (!buffer || !capacity || !operation) return;
    used = strlen(buffer);
    if (used && used + 1 < capacity) {
        buffer[used++] = ',';
        buffer[used] = 0;
    }
    if (used < capacity - 1) strncat(buffer, operation, capacity - used - 1);
}

static int selected_user_index(CLI_USER *users, int count, CLI_USER *selected)
{
    int i;
    for (i = 0; i < count; ++i) if (&users[i] == selected) return i;
    return -1;
}

static int emit_mutation_result(const CLI_OPTIONS *o, const char *sam, const CLI_USER *user, const char *operation)
{
    int close_file = 0;
    FILE *f = open_output(o->output_path, &close_file);
    if (!f) return EXIT_IO;
    if (o->format == FORMAT_JSON) {
        fprintf(f, "{\"schemaVersion\": 1, \"tool\": \"ntpwcli\", \"version\": \"%s\", \"success\": true, \"operation\": \"", NTPWCLI_VERSION);
        json_escape(f, operation); fprintf(f, "\", \"samPath\": \""); json_escape(f, sam);
        fprintf(f, "\", \"user\": "); emit_user_json(f, user); fprintf(f, "}\n");
    } else if (!o->quiet) {
        fprintf(f, "Operation completed: %s for %s (RID %d).\n", operation, user->name, user->rid);
    }
    if (close_file) fclose(f);
    return EXIT_OK;
}

int ntpwcli_run(int argc, char **argv)
{
    CLI_OPTIONS options;
    CLI_INSTALLATION installations[CLI_MAX_DISCOVERED];
    CLI_USER *users = NULL;
    CLI_USER *selected = NULL;
    char sam_path[CLI_MAX_PATH];
    char password[CLI_PASSWORD_MAX + 1];
    char operations[160];
    int installation_count;
    int user_count;
    int rc;
    int source_count;
    int action_count;
    int state_action_count;
    int password_action_count;
    int mutation_requested;
    int selected_index = -1;
    int result = EXIT_OK;

    /* User names and JSON are emitted as UTF-8. This also improves console display
       for non-ASCII local account names without affecting redirected output. */
    SetConsoleOutputCP(CP_UTF8);

    if (!parse_options(argc, argv, &options)) {
        print_usage();
        return EXIT_USAGE;
    }
    if (argc == 1 || options.show_help) {
        print_usage();
        return EXIT_OK;
    }
    if (options.show_version) {
        puts("ntpwcli " NTPWCLI_VERSION);
        return EXIT_OK;
    }

    mutation_requested = options.action_unlock || options.action_enable || options.action_disable ||
        options.action_unlock_enable || options.action_password_prompt || options.action_password_stdin ||
        options.action_password_file || options.action_password_blank;

    state_action_count = options.action_unlock + options.action_enable + options.action_disable +
        options.action_unlock_enable;
    password_action_count = options.action_password_prompt + options.action_password_stdin +
        options.action_password_file + options.action_password_blank;
    if (state_action_count > 1) {
        fprintf(stderr, "Choose only one account-state action: /unlock, /enable, /disable, or /unlock-enable.\n");
        return EXIT_USAGE;
    }
    if (password_action_count > 1) {
        fprintf(stderr, "Choose only one password action.\n");
        return EXIT_USAGE;
    }
    if (options.user_name && options.rid_text) {
        fprintf(stderr, "Specify either /user or /rid, not both.\n");
        return EXIT_USAGE;
    }

    action_count = options.action_discover + options.action_list + options.action_status +
        options.action_backup + options.action_restore + (mutation_requested ? 1 : 0);
    if (action_count != 1) {
        fprintf(stderr, "Specify exactly one primary action. A state action may be combined with one password action.\n");
        return EXIT_USAGE;
    }

    if (options.action_discover) {
        installation_count = discover_installations(installations, CLI_MAX_DISCOVERED);
        return emit_discovery(installations, installation_count, options.format, options.output_path);
    }

    source_count = (options.sam ? 1 : 0) + (options.windows_path ? 1 : 0) + (options.auto_discover ? 1 : 0);
    if (source_count != 1) {
        fprintf(stderr, "Specify exactly one source: /sam, /windows, or /auto.\n");
        return EXIT_USAGE;
    }

    rc = resolve_sam_path(&options, sam_path, sizeof(sam_path));
    if (rc != EXIT_OK) {
        if (rc == EXIT_IO) fprintf(stderr, "Offline SAM was not found or cannot be read.\n");
        else if (rc == EXIT_USAGE) fprintf(stderr, "Specify /sam, /windows, or /auto.\n");
        else if (rc == EXIT_VALIDATION) fprintf(stderr, "The selected discovery index is invalid.\n");
        return rc;
    }

    if (options.action_backup) {
        rc = backup_hive_set(sam_path, options.backup_dir);
        if (rc != EXIT_OK) return rc;
        return emit_hive_operation_result(&options, sam_path, "backup", options.backup_dir);
    }
    if (options.action_restore) {
        if (!options.confirm || strcmp(options.confirm, "RESTORE") != 0) {
            fprintf(stderr, "Restore requires --confirm RESTORE.\n");
            return EXIT_CONFIRM;
        }
        rc = restore_hive_set(sam_path, options.restore_dir);
        if (rc != EXIT_OK) return rc;
        return emit_hive_operation_result(&options, sam_path, "restore", options.restore_dir);
    }

    users = (CLI_USER *)calloc(CLI_MAX_USERS, sizeof(*users));
    if (!users) {
        fprintf(stderr, "Unable to allocate the local-user inventory buffer.\n");
        return EXIT_IO;
    }

    user_count = load_users(sam_path, users, CLI_MAX_USERS);
    if (user_count < 0) {
        fprintf(stderr, "Unable to open or enumerate SAM: %s\n", sam_path);
        result = EXIT_IO;
        goto cleanup;
    }

    if (options.action_list) {
        if (options.user_name || options.rid_text) {
            selected = find_user(users, user_count, options.user_name, options.rid_text);
            if (!selected) {
                fprintf(stderr, "Requested local user was not found.\n");
                result = EXIT_USER_NOT_FOUND;
                goto cleanup;
            }
            selected_index = selected_user_index(users, user_count, selected);
        }
        result = emit_users(users, user_count, sam_path, options.format, options.output_path, selected_index);
        goto cleanup;
    }

    if (options.action_status) {
        selected = find_user(users, user_count, options.user_name, options.rid_text);
        if (!selected) {
            fprintf(stderr, "Status requires an existing /user or /rid.\n");
            result = EXIT_USER_NOT_FOUND;
            goto cleanup;
        }
        selected_index = selected_user_index(users, user_count, selected);
        result = emit_users(users, user_count, sam_path, options.format, options.output_path, selected_index);
        goto cleanup;
    }

    if (!options.confirm || strcmp(options.confirm, "WRITE") != 0) {
        fprintf(stderr, "SAM mutation requires --confirm WRITE.\n");
        result = EXIT_CONFIRM;
        goto cleanup;
    }

    selected = find_user(users, user_count, options.user_name, options.rid_text);
    if (!selected) {
        fprintf(stderr, "Mutation requires an existing /user or /rid.\n");
        result = EXIT_USER_NOT_FOUND;
        goto cleanup;
    }
    if (is_hives_ro()) {
        fprintf(stderr, "The SAM hive is read-only.\n");
        result = EXIT_IO;
        goto cleanup;
    }

    operations[0] = 0;
    if (options.action_unlock_enable) {
        if (!clear_account_lockout(selected->rid) || !set_account_enabled(selected->rid, 1)) {
            fprintf(stderr, "Unlock/enable operation failed.\n");
            result = EXIT_MUTATION;
            goto cleanup;
        }
        append_operation(operations, sizeof(operations), "unlock+enable");
    } else {
        if (options.action_unlock) {
            if (!clear_account_lockout(selected->rid)) {
                fprintf(stderr, "Unlock operation failed.\n");
                result = EXIT_MUTATION;
                goto cleanup;
            }
            append_operation(operations, sizeof(operations), "unlock");
        }
        if (options.action_enable) {
            if (!set_account_enabled(selected->rid, 1)) {
                fprintf(stderr, "Enable operation failed.\n");
                result = EXIT_MUTATION;
                goto cleanup;
            }
            append_operation(operations, sizeof(operations), "enable");
        }
        if (options.action_disable) {
            if (!set_account_enabled(selected->rid, 0)) {
                fprintf(stderr, "Disable operation failed.\n");
                result = EXIT_MUTATION;
                goto cleanup;
            }
            append_operation(operations, sizeof(operations), "disable");
        }
    }

    if (password_action_count == 1) {
        memset(password, 0, sizeof(password));
        if (options.action_password_blank) {
            password[0] = 0;
        } else if (options.action_password_file) {
            rc = read_password_file(options.password_file, password, sizeof(password));
            if (rc < 0) {
                fprintf(stderr, "Password file cannot be read: %s\n", options.password_file);
                result = EXIT_IO;
                goto cleanup;
            }
            if (rc == 0) {
                fprintf(stderr, "Password file is empty due to EOF or contains more than %d characters.\n", CLI_PASSWORD_MAX);
                result = EXIT_VALIDATION;
                goto cleanup;
            }
        } else if (options.action_password_stdin) {
            if (!read_password_line(stdin, password, sizeof(password))) {
                fprintf(stderr, "Password stdin input is unavailable or exceeds %d characters.\n", CLI_PASSWORD_MAX);
                result = EXIT_CANCELLED;
                goto cleanup;
            }
        } else {
            rc = read_password_hidden(password, sizeof(password));
            if (rc < 0) {
                result = EXIT_VALIDATION;
                goto cleanup;
            }
            if (rc == 0) {
                fprintf(stderr, "Password input was cancelled.\n");
                result = EXIT_CANCELLED;
                goto cleanup;
            }
        }

        if (!options.action_password_blank && password[0] == 0) {
            SecureZeroMemory(password, sizeof(password));
            fprintf(stderr, "An empty password is allowed only with /password-blank.\n");
            result = EXIT_VALIDATION;
            goto cleanup;
        }

        if (!change_password(selected->rid, password)) {
            SecureZeroMemory(password, sizeof(password));
            fprintf(stderr, "Password operation failed.\n");
            result = EXIT_MUTATION;
            goto cleanup;
        }
        SecureZeroMemory(password, sizeof(password));
        append_operation(operations, sizeof(operations), options.action_password_blank ? "clear-password" : "set-password");
    }

    if (!write_hives()) {
        fprintf(stderr, "Writing the SAM hive failed.\n");
        result = EXIT_WRITE;
        goto cleanup;
    }
    if (!get_account_status(selected->rid, &selected->status)) {
        fprintf(stderr, "The change was written, but refreshed account status could not be read.\n");
        result = EXIT_IO;
        goto cleanup;
    }
    result = emit_mutation_result(&options, sam_path, selected, operations);

cleanup:
    SecureZeroMemory(password, sizeof(password));
    close_hives();
    if (users) {
        SecureZeroMemory(users, CLI_MAX_USERS * sizeof(*users));
        free(users);
    }
    return result;
}
