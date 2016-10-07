
#ifdef A20
#endif

#ifdef OSX
#endif

#define HTTPS_ADDRESS "https://petbot.ca:5000/"
#define HTTPS_ADDRESS_AUTH HTTPS_ADDRESS "AUTH"
#define HTTPS_ADDRESS_QRCODE_JSON HTTPS_ADDRESS "PB_QRCODE_JSON"
#define HTTPS_ADDRESS_SETUP_CHECK HTTPS_ADDRESS "SETUP/CHECK"
#define HTTPS_ADDRESS_PB_REGISTER HTTPS_ADDRESS "PB_REGISTER"

//#define PBPRINTF(fmt, args...)    fprintf(stderr, fmt, ## args)
#define PBPRINTF(fmt, args...) fprintf(stderr, "DEBUG: %s:%d:%s(): " fmt, \
    __FILE__, __LINE__, __func__, ##args)

extern char * pb_path;
extern char * pb_config_path;
extern char * pb_tmp_path;
extern int pty_master, pty_slave;

char * next_tok(char * str, char d);
void kill_pid(int * pid) ;
int file_exists(char * f );
int mount_config_rw();
int mount_config_ro();
int mount_root_ro();
int mount_root_rw();
void pbchown(const char * fp, const char *  un, const char * gn);
void pbtouch(char *fn);
void register_sig_handlers();
char * pbcat(char * a, char * b );
void pbdelay(int d);
char * pbID();
char * executable_path();
char * pb_readFile(char * fn);
char * pb_writeFile(char *fn, void *d , size_t sz);
char * pb_rewrite(char * config, char * output_fn, char ** keys, char ** values, int n) ;
