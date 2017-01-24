#ifndef PB_HEADER
#define PB_HEADER


#define RELEASE 1

#ifdef TARGET_OS_IPHONE
#include <agent.h>
//#import <CocoaLumberjack/CocoaLumberjack.h>
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#else 
#include <nice/agent.h>
#endif

#ifdef A20
#endif

#ifdef OSX
#endif


#define HTTPS_ADDRESS_PB_STATIC HTTPS_ADDRESS "static/"
#define HTTPS_ADDRESS_DEAUTH HTTPS_ADDRESS "DEAUTH"
#define HTTPS_ADDRESS "https://petbot.ca:5000/"
#define HTTPS_ADDRESS_AUTH HTTPS_ADDRESS "AUTH"
#define HTTPS_ADDRESS_QRCODE_JSON HTTPS_ADDRESS "PB_QRCODE_JSON"
#define HTTPS_ADDRESS_SETUP_CHECK HTTPS_ADDRESS "SETUP/CHECK"
#define HTTPS_ADDRESS_PB_REGISTER HTTPS_ADDRESS "PB_REGISTER"
#define HTTPS_ADDRESS_PB_LISTEN HTTPS_ADDRESS "SETUP/LISTEN"
#define HTTPS_ADDRESS_PB_PING HTTPS_ADDRESS "SETUP/PING"
#define HTTPS_ADDRESS_PB_LS HTTPS_ADDRESS "FILES_LS/"
#define HTTPS_ADDRESS_PB_DL HTTPS_ADDRESS "FILES_DL/"
#define HTTPS_ADDRESS_PB_UL HTTPS_ADDRESS "FILES_UL/"
#define HTTPS_ADDRESS_PB_SELFIE HTTPS_ADDRESS "FILES_SELFIE/"
#define HTTPS_ADDRESS_PB_RM HTTPS_ADDRESS "FILES_RM/"
#define HTTPS_ADDRESS_PB_WAIT HTTPS_ADDRESS "WAIT"
#define HTTPS_ADDRESS_PB_SELFIE_COUNT HTTPS_ADDRESS "FILES_SELFIE_COUNT/"
#define HTTPS_ADDRESS_PB_SELFIE_LAST HTTPS_ADDRESS "FILES_SELFIE_LAST/"

#define SELFIE_TIMEOUT 3600
 
#define SOUND_MAX_RECORD 10

#define SELFIE_FN "/tmp/selfie.mov"

//#define PBPRINTF(fmt, args...)    fprintf(stderr, fmt, ## args)
#ifndef RELEASE
#define PBPRINTF(fmt, args...) fprintf(stderr, "DEBUG: %s:%d:%s(): " fmt, \
__FILE__, __LINE__, __func__, ##args)
#else 
#define PBPRINTF(fmt, args...) do {} while (0)
#endif

typedef struct DeviceSID {
  uint32_t key0;
  uint32_t key1;
  uint32_t key2;
  uint32_t key3;
} DeviceSID;


typedef struct pb_nice_io {
   NiceAgent *agent;
   guint stream_id;
   GIOChannel * gpipe;
   guint pipe_to_parent;
   guint pipe_to_child;
   guint pipe_from_parent;
   guint pipe_from_child;
   guint controlling;
   gboolean negotiation_done;
   GCond negotiate_cond;
   GMutex negotiate_mutex;
   char * our_nice;
   char * other_nice;
    char * error;
} pb_nice_io;

extern char * stun_addr;
extern int stun_port;
extern char * stun_user;
extern char * stun_passwd;

#ifndef TARGET_OS_IPHONE


extern float selfie_dog_sensitivity;
extern float selfie_cat_sensitivity;
extern float selfie_pet_sensitivity;
extern float selfie_mot_sensitivity;
extern float selfie_person_sensitivity;
extern int selfie_timeout;
extern int selfie_length;
extern int stddev_multiplier;
extern long master_volume;
extern int pb_color_fx;
extern int pb_exposure;
extern int pb_hflip;
extern int pb_vflip;
extern int pb_white_balance;

extern char * pb_path;
extern char * pb_config_path;
extern char * pb_tmp_path;
extern char * pb_config_file_path;
extern int pty_master, pty_slave;

char *randstring(int length);
void * get_next_token(char ** s) ;
float xor_float(float f, char chewbacca);
int cp(const char *to , const char * from);
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

void pb_config_read();
void pb_config_write();
int set_config(char * pname, char * v_str);

DeviceSID * getSID();
#endif
#endif
