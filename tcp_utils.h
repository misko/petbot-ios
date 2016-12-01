#ifndef __PB_TCP_UTILS__
#define __PB_TCP_UTILS__ 1

#include <stdio.h>
#include <string.h>
#include <stdint.h>

#ifdef PBSSL
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#define CHK_NULL(x) if ((x)==NULL) exit (1)
#define CHK_ERR(err,s) if ((err)==-1) { perror(s); exit(1); }
#define CHK_SSL(err) if ((err)==-1) { ERR_print_errors_fp(stderr); exit(2); }
#endif

#ifdef PBTHREADS
#include <pthread.h>
#define PBTHREAD_DEFAULT_KEEP_ALIVE 6
#endif

typedef enum {
	PBSOCK_CONNECTED,
	PBSOCK_DISCONNECTED,
 	PBSOCK_CONNECTING,
	PBSOCK_UNKNOWN,
	PBSOCK_EXIT
} pbsock_state;

extern const char * PBMSG_TYPES_STRING[];


typedef enum {
	PBMSG_FAIL = (1<<0),
	PBMSG_SUCCESS = (1<<1),
	PBMSG_BUSY = (1<<2),
	PBMSG_REQUEST = (1<<3),
	PBMSG_RESPONSE = (1<<4), 
	PBMSG_EVENT = (1<<5), 
	PBMSG_VIDEO = (1<<6),
	PBMSG_ICE = (1<<7),
	PBMSG_COOKIE = (1<<8),
	PBMSG_SOUND = (1<<9),
	PBMSG_WIFI = (1<<10),
	PBMSG_LED = (1<<11),
	PBMSG_CLIENT = (1<<12),
	PBMSG_SERVER = (1<<13),
	PBMSG_ALL = (1<<14),
	PBMSG_CONFIG_SET = (1<<15),
	PBMSG_CONFIG_GET = (1<<16),
        PBMSG_CONNECTED = (1<<17),
        PBMSG_DISCONNECTED = (1<<18),
        PBMSG_STRING = (1<<19),
        PBMSG_PTR = (1<<20),
        PBMSG_BIN = (1<<21),
        PBMSG_FILE = (1<<22),
	PBMSG_KEEP_ALIVE = (1<<23),
	PBMSG_GPIO = (1<<24),
	PBMSG_UPDATE = (1<<25),
	PBMSG_SYSTEM = (1<<26)
} pbmsg_type;

#define PBMSG_MAX_TYPE 26

typedef struct pbmsg {
	uint32_t pbmsg_type;
	uint32_t pbmsg_len;
	uint32_t pbmsg_from; // filled in by BB server - using unqiue ID per client
	char * pbmsg; 
} pbmsg;
typedef struct pbsock {
#ifdef PBSSL
	SSL*     ssl;
#endif
#ifdef PBTHREADS
	pthread_t keep_alive_thread;
	pthread_mutex_t send_mutex;
	pthread_mutex_t recv_mutex;
	pthread_mutex_t waiting_threads_mutex;
	pthread_cond_t cond;
	int keep_alive_time;
	int waiting_threads; //need to hold pbs->send_mutex to modify this!
#endif
	int client_sock;
	pbsock_state state;
} pbsock;

#if defined __cplusplus
extern "C" {
#endif

void free_pbsock(pbsock *pbs);

//use these as an interface so can later call callback function on state change
//otherwise state changes just inline in code and not wrapped
void pbsock_set_state(pbsock * pbs, pbsock_state);
pbsock_state pbsock_get_state(pbsock *pbs);
#ifdef PBTHREADS
void *keep_alive_handler(void * v );
pbsock_state pbsock_wait_state(pbsock * pbs);

int increment_waiting_threads(pbsock * pbs);
int decrement_waiting_threads(pbsock * pbs);

#endif

#ifdef PBSSL
pbsock* new_pbsock(int client_sock, SSL_CTX* ctx, int accept);
pbsock* connect_to_server_with_key(const char * hostname, int portno, SSL_CTX*ctx, const char * key);
pbsock* connect_to_server(const char * hostname, int portno, SSL_CTX* ctx);
#else
pbsock* new_pbsock(int client_sock);
pbsock* connect_to_server_with_key(const char * hostname, int portno, const char * key);
pbsock* connect_to_server(const char * hostname, int portno);
#endif
char * pbsock_state_to_string(pbsock * pbs) ;

extern char * bb_new_user;

void free_pbmsg(pbmsg * m);
pbmsg * new_pbmsg();
pbmsg * new_pbmsg_from_str_wtype(const char * s, int type);
pbmsg * new_pbmsg_from_str(const char *s);
pbmsg * new_pbmsg_from_file(const char *s);
pbmsg * new_pbmsg_from_ptr(void * x );
pbmsg * new_pbmsg_from_ptr_and_int(void *x , int z);
int pbmsg_to_file(pbmsg * m, const char * fn);
//Send / recv pbmsg over pbsock
pbmsg * recv_pbmsg(pbsock * pbs);
pbmsg * recv_all_pbmsg(pbsock * pbs,int read_all);
size_t send_pbmsg(pbsock *, pbmsg *m);
//Send / recv pbmsg over file descriptor
pbmsg * recv_fd_pbmsg(int fd);
pbmsg * recv_all_fd_pbmsg(int fd,int read_all);
size_t send_fd_pbmsg(int fd, pbmsg *m);

char * read_file(const char *fn, size_t * len);
int write_file(const char *fn , char * buffer, size_t len);

char * pbmsg_type_to_string(pbmsg *m) ;
int pbmsg_has_type(pbmsg *m, int ty);
#endif

unsigned int pbmsg_hash(const char *str);

#if defined __cplusplus
};
#endif
