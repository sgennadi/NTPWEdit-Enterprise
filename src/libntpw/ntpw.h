#ifndef __NTPW_H__
#define __NTPW_H__

enum HIVE_ID {H_SAM=0, /*H_SYS, H_SEC, H_SOF,*/ H_COUNT};

struct user_info
    {
    int rid;
    char *unicode_name;
    };

struct search_user
    {
    int count;
    int countri;
    int nkofs;
    };

int open_hives(char *fname[H_COUNT]);
void close_hives(void);
int is_hives_dirty(void);
int is_hives_ro(void);
int write_hives(void);
struct user_info *first_user(struct search_user *su);
struct user_info *next_user(struct search_user *su);
/* NTPWEDIT_ENTERPRISE_ACCOUNT_STATUS_BEGIN */
struct account_status
    {
    unsigned short acb_bits;
    unsigned short failed_count;
    unsigned short login_count;
    int lockout_threshold;
    int disabled;
    int auto_locked;
    int locked_by_count;
    int locked;
    int password_never_expires;
    int password_not_required;
    int normal_account;
    };
int get_account_status(int rid, struct account_status *status);
int clear_account_lockout(int rid);
int set_account_enabled(int rid, int enabled);
/* NTPWEDIT_ENTERPRISE_ACCOUNT_STATUS_END */

int is_account_locked(int rid);
int unlock_account(int rid);
int change_password(int rid, char *password);

#endif /* __NTPW_H__*/
