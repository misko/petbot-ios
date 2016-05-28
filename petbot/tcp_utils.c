#include<stdio.h>
#include<string.h>    //strlen
#include<stdlib.h>    //strlen
#include<sys/socket.h>
#include<arpa/inet.h> //inet_addr
#include<unistd.h>    //write
#include<pthread.h> //for threading , link with lpthread
#include "tcp_utils.h"
#include "assert.h"
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h> 
#include <sys/select.h>
/* According to earlier standards */
#include <sys/time.h>
#include <sys/types.h>
#include <strings.h>
#define h_addr h_addr_list[0] /* for backward compatibility */
#include <string.h>
#include <signal.h>

#ifdef PBSSL
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif


#ifdef PBSSL
pbsock * new_pbsock(int client_sock, SSL_CTX* ctx, int accept);
pbsock* connect_to_server_with_key(const char * hostname, int portno, SSL_CTX*ctx, const char * key);
pbsock* connect_to_server(const char * hostname, int portno, SSL_CTX* ctx);
#else
pbsock * new_pbsock(int client_sock);
pbsock* connect_to_server_with_key(const char * hostname, int portno, const char * key);
pbsock* connect_to_server(const char * hostname, int portno);
#endif


#ifdef PBSSL
pbsock * connect_to_server_with_key(const char * hostname, int portno, SSL_CTX* ctx, const char * key) {
	pbsock *pbs = connect_to_server(hostname,portno,ctx);
#else
pbsock * connect_to_server_with_key(const char * hostname, int portno, const char * key) {
	pbsock *pbs = connect_to_server(hostname,portno);
#endif
	if (pbs==NULL ){
		return NULL;
	}
	pbmsg * m = new_pbmsg_from_str(key);
	send_pbmsg(pbs,m);
	free_pbmsg(m);
	fprintf(stderr,"CONNECTED TO SERVER\n");
	return pbs;
}

#ifdef PBSSL
pbsock* connect_to_server(const char * hostname, int portno, SSL_CTX* ctx) {
#else
pbsock* connect_to_server(const char * hostname, int portno) {
#endif
    /* socket: create the socket */
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0)  {
	fprintf(stderr,"Failed to socket\n");
	return NULL;
    } 

    /* gethostbyname: get the server's DNS entry */
    struct hostent *server;
    assert(hostname!=NULL);
    server = gethostbyname(hostname);
    if (server == NULL) {
        fprintf(stderr,"ERROR, no such host as %s\n", hostname);
	return NULL;
    }
    struct sockaddr_in serveraddr;

    /* build the server's Internet address */
    bzero((char *) &serveraddr, sizeof(serveraddr));
    serveraddr.sin_family = AF_INET;
    bcopy((char *)server->h_addr, 
	  (char *)&serveraddr.sin_addr.s_addr, server->h_length);
    serveraddr.sin_port = htons(portno);

    /* connect: create a connection with the server */
    if (connect(sockfd, (const struct sockaddr*)&serveraddr, sizeof(serveraddr)) < 0)  {
	fprintf(stderr,"Failed to socket\n");
	return NULL;
    }
#ifdef PBSSL
    pbsock * pbs =  new_pbsock(sockfd,ctx,0);
#else
    pbsock * pbs =  new_pbsock(sockfd);
#endif
    return pbs;
}

void *keep_alive_handler(void * v ) {
	fprintf(stderr,"Keep alive handler here\n");
	signal(SIGPIPE, SIG_IGN); // ignore sigpipe
	pbmsg * m=new_pbmsg();
	m->pbmsg_type = PBMSG_KEEP_ALIVE;
	pbsock * pbs = (pbsock *) v;
	struct timeval tv;
	struct timespec ts;
	while (pbs->state!=PBSOCK_EXIT) {
		gettimeofday(&tv, NULL);
		ts.tv_sec = tv.tv_sec + pbs->keep_alive_time;
		ts.tv_nsec = 0;	
		if (pthread_mutex_lock(&(pbs->send_mutex))!=0) {
			fprintf(stderr,"Keep alive failed to grab send mutex\n");
			exit(1);
		}
		pthread_cond_timedwait(&(pbs->cond), &(pbs->send_mutex), &ts);
		pthread_mutex_unlock(&(pbs->send_mutex));
		//sleep(pbs->keep_alive_time);
		if (send_pbmsg(pbs, m)!=8) {
			fprintf(stderr,"KEEP ALIVE HAS DETECTED A DISCONNECT!\n");
			//other side disconnected!
			assert(pbs->state!=PBSOCK_CONNECTED);
			//TODO CALL A HANDLER? SEND A SIGNAL? UNLOCK A MUTEX?
			//break;
		} else {
			fprintf(stderr,"SENT KEEP ALIVE!\n");
		}	
	}
	fprintf(stderr,"Keep alive handler exit\n");
	if (pthread_mutex_lock(&(pbs->send_mutex))!=0) {
		fprintf(stderr,"Keep alive failed to grab send mutex\n");
		exit(1);
	}
	int retries=10;
	while (pbs->waiting_threads>0 && retries>0) {
		gettimeofday(&tv, NULL);
		ts.tv_sec = tv.tv_sec + pbs->keep_alive_time;
		ts.tv_nsec = 0;	
		pthread_cond_wait(&(pbs->cond),&(pbs->send_mutex));
		fprintf(stderr,"Still waiting on waiting threads to exit... %d\n",retries);
		retries--;
	}
	pthread_mutex_unlock(&(pbs->send_mutex));
	
	free_pbsock(pbs);
	return NULL;
}

#ifdef PBSSL
pbsock * new_pbsock(int client_sock, SSL_CTX* ctx, int accept) {
#else
pbsock * new_pbsock(int client_sock) {
#endif
	pbsock * pbs = (pbsock*)calloc(1,sizeof(pbsock));
	if (pbs==NULL) {
		fprintf(stderr,"Failed to amlloc pbssock\n");
		return NULL;
	}
	pbs->state=PBSOCK_CONNECTING;
	pbs->waiting_threads=0;
	pbs->client_sock = client_sock;
#ifdef PBSSL
	pbs->ssl = SSL_new (ctx);
	if (pbs->ssl==NULL ){
		fprintf(stderr,"Failed to do something with ssl?\n");
		close(pbs->client_sock);
		free(pbs);
		return NULL;
	}                        
	SSL_set_fd (pbs->ssl, pbs->client_sock);
	int err=0;
	if (accept==1) {
		err = SSL_accept (pbs->ssl);                     
	} else {
		err = SSL_connect (pbs->ssl);                   	
	}
    if (err==-1 || strcmp(SSL_get_cipher (pbs->ssl),"NONE")==0){
		fprintf(stderr, "Whoops .. no SSL???\n");
		free_pbsock(pbs);
		return NULL;
	}
	printf ("SSL connection using %s\n", SSL_get_cipher (pbs->ssl));
#endif
	pbs->state=PBSOCK_CONNECTED;
#ifdef PBTHREADS
	pbs->keep_alive_time=PBTHREAD_DEFAULT_KEEP_ALIVE;
	if (pthread_mutex_init(&(pbs->send_mutex), NULL) != 0) {
		fprintf(stderr,"Failed to init pbthreads send mutex\n");
		free_pbsock(pbs);
		return NULL;
	}
	if (pthread_mutex_init(&(pbs->recv_mutex), NULL) != 0) {
		fprintf(stderr,"Failed to init pbthreads recv mutex\n");
		pthread_mutex_destroy(&(pbs->send_mutex));
		free_pbsock(pbs);
		return NULL;
	}
	if (pthread_cond_init(&(pbs->cond), NULL) != 0) {
		fprintf(stderr,"Failed to init pbthreads cond\n");
		pthread_mutex_destroy(&(pbs->send_mutex));
		pthread_mutex_destroy(&(pbs->recv_mutex));
		free_pbsock(pbs);
		return NULL;
	}
	if (pthread_create( &(pbs->keep_alive_thread) , NULL ,  keep_alive_handler , pbs) < 0) { 
		fprintf(stderr,"Failed to create pthread for keep alive\n");
		free_pbsock(pbs);
		return NULL;
	}
#endif
	return pbs;
}

void pbsock_set_state(pbsock * pbs, pbsock_state state) {
	pbs->state=state;
#ifdef PBTHREADS
	pthread_cond_broadcast(&(pbs->cond));
#endif
}

//TODO might miss a statechange! if state changes back to original state quickyly - do we care?
pbsock_state pbsock_wait_state(pbsock *pbs) {
	if (pbs->state==PBSOCK_EXIT) {
		return PBSOCK_EXIT; //if we are trying to kill the socket dont take any more waiters
	}
	if (pthread_mutex_lock(&(pbs->send_mutex))!=0) {
		fprintf(stderr,"Failed to get send lock for wait state!\n");
		exit(1);
	}
	pbs->waiting_threads++;
	pbsock_state old_state = pbs->state;
	while (old_state==pbs->state) {
		fprintf(stderr,"THREAD WAITING ON STATE CHANGE\n");
		if (pthread_cond_wait(&(pbs->cond),&(pbs->send_mutex))!=0) {
			fprintf(stderr,"Failed to wait on cond...\n");
			exit(1);
		}

	}
	pbs->waiting_threads--;
	pbsock_state new_state = pbs->state;
	fprintf(stderr,"THREAD DONE WAITING ON STATE CHANGE\n");
	pthread_mutex_unlock(&(pbs->send_mutex));
	pthread_cond_broadcast(&(pbs->cond));
	return new_state;
}

void free_pbsock(pbsock *pbs) {
	//TODO SYNCHRONIZATION?
	if (pbs->client_sock>=0) {
		close(pbs->client_sock);
		pbs->client_sock=-1;
	}
	#ifdef PBTHREADS
	if (pthread_self()==pbs->keep_alive_thread) {
		fprintf(stderr,"Cleaning out from child thread\n");
		pthread_mutex_destroy(&(pbs->send_mutex));
		pthread_mutex_destroy(&(pbs->recv_mutex));
		pthread_cond_destroy(&(pbs->cond));
		#ifdef PBSSL
		if (pbs->ssl!=NULL) {
			SSL_free(pbs->ssl);
			pbs->ssl=0;
		}
		#endif
		free(pbs);
	} else if (pbs->keep_alive_thread!=0) {
		fprintf(stderr,"Setting state to exit\n");
		pbsock_set_state(pbs,PBSOCK_EXIT);
	} else if (pbs->keep_alive_thread==0) {
		fprintf(stderr,"Cleaning out thread never started\n");
		#ifdef PBSSL
		if (pbs->ssl!=NULL) {
			SSL_free(pbs->ssl);
			pbs->ssl=0;
		}
		#endif
		free(pbs);
	}
	#else
	free(pbs);
	#endif
}


char * bb_new_user = "welcome new user!";


void free_pbmsg(pbmsg * m ) {
	if (m->pbmsg!=NULL) {
		free(m->pbmsg);
	}
	free(m);
}



pbmsg * new_pbmsg() {
	pbmsg * m = (pbmsg*)malloc(sizeof(pbmsg));
	if (m==NULL) {
		fprintf(stderr,"Failed to malloc bare pbmsg\n");
		return NULL;
	}
	m->pbmsg_len=0;
	m->pbmsg_type=PBMSG_UNKNOWN;
	m->pbmsg=NULL;
	return m;
}

pbmsg * new_pbmsg_from_str(const char * s) {
	pbmsg * m = new_pbmsg();
	m->pbmsg_len=strlen(s)+1;
	m->pbmsg=strdup(s);
	m->pbmsg_type=PBMSG_MESSAGE;
	return m;
}

pbmsg * recv_pbmsg(pbsock *pbs) {
	if (pbs->state!=PBSOCK_CONNECTED) {
		return NULL;
	}
#ifdef PBTHREADS 
	if (pthread_mutex_lock(&(pbs->recv_mutex))!=0) {
		fprintf(stderr,"FAILED TO LOCK!\n");
		return NULL;
	}
#endif
	pbmsg * m;
#ifdef PBSSL // WITH SSL
	m=new_pbmsg();
	int read_size=0;
	do {
		read_size = SSL_read (pbs->ssl, &m->pbmsg_len, 4);                 
		read_size += SSL_read (pbs->ssl, &m->pbmsg_type, 4);                 
		if (read_size!=8) {
			fprintf(stderr,"Failed to recieve correct size... %d\n",read_size);
			pbs->state=PBSOCK_DISCONNECTED;
			#ifdef PBTHREADS
			pthread_mutex_unlock(&(pbs->recv_mutex));
			#endif
			free_pbmsg(m);
			return NULL;
		}
		if ( (m->pbmsg_type & PBMSG_KEEP_ALIVE) !=0 ) {
			//fprintf(stderr,"GOT A KEEP ALIVE\n");
		}
	} while ( (m->pbmsg_type & PBMSG_KEEP_ALIVE) !=0);
	//read the payload
	m->pbmsg = (char*)malloc(sizeof(char)*m->pbmsg_len);
	if (m->pbmsg==NULL) {
		fprintf(stderr,"Failed to malloc data for pbmsg\n");
		#ifdef PBTHREADS
		pthread_mutex_unlock(&(pbs->recv_mutex));
		#endif
		free_pbmsg(m);
		return NULL;
	}
	read_size=0;
	while (read_size<m->pbmsg_len) {
		int ret = SSL_read(pbs->ssl,m->pbmsg,m->pbmsg_len); 
		if (ret==0 || ret<0) {
			fprintf(stderr,"Something failed in read of TCP socket\n");
			#ifdef PBTHREADS
			pthread_mutex_unlock(&(pbs->recv_mutex));
			#endif
			free_pbmsg(m);
			return NULL;
		}
		read_size+=ret;
	}
#else /// WITHOUT SSL
	m=recv_fd_pbmsg(pbs->client_sock);
#endif
	#ifdef PBTHREADS
	pthread_mutex_unlock(&(pbs->recv_mutex));
	#endif
	return m;
}

size_t send_pbmsg(pbsock *pbs, pbmsg * m) {
	if (pbs->state!=PBSOCK_CONNECTED) {
		return 0;
	}
#ifdef PBTHREADS 
	if (pthread_mutex_lock(&(pbs->send_mutex))!=0) {
		fprintf(stderr,"FAILED TO LOCK!\n");
		return 0;
	}
#endif
	int ret=0;
#ifdef PBSSL
	//send the length and type
	int r = SSL_write(pbs->ssl, &m->pbmsg_len, 4); 
	r += SSL_write(pbs->ssl, &m->pbmsg_type, 4); 
	if (r!=8) {
		pbsock_set_state(pbs,PBSOCK_DISCONNECTED);
		#ifdef PBTHREADS
		pthread_mutex_unlock(&(pbs->send_mutex));
		#endif
		fprintf(stderr,"Failed to send_pbmsg write length\n");
		return 0;
	}
	ret+=r; //keep track of how many bytes sent
	//send the message
	if (m->pbmsg_len>0) {
		r = SSL_write(pbs->ssl, m->pbmsg, m->pbmsg_len);
		if (r!=m->pbmsg_len) {
			fprintf(stderr,"Failed to send message write\n");
			#ifdef PBTHREADS
			pthread_mutex_unlock(&(pbs->send_mutex));
			#endif
			return 0;
		}	
		ret+=r;
	}
#else 
	ret=send_fd_pbmsg(pbs->client_sock,m);
#endif
	#ifdef PBTHREADS
	pthread_mutex_unlock(&(pbs->send_mutex));
	#endif
	return ret;
}

pbmsg * recv_fd_pbmsg(int fd) {
	pbmsg * m = new_pbmsg(); 
	//read the msglen
	size_t read_size=0;
	do {
		read_size = read(fd,&m->pbmsg_len, 4);
		read_size += read(fd,&m->pbmsg_type, 4);
		if (read_size!=8) {
			free_pbmsg(m);
			return NULL;
		}
		if ((m->pbmsg_type & PBMSG_KEEP_ALIVE) !=0) {
			//fprintf(stderr,"GOT A KEEP ALIVE FD\n");
		}
	} while ( (m->pbmsg_type & PBMSG_KEEP_ALIVE) !=0);
	//now read the msg
	m->pbmsg = (char*)malloc(sizeof(char)*m->pbmsg_len);
	if (m->pbmsg==NULL) {
		fprintf(stderr,"Failed to malloc data for pbmsg\n");
		free_pbmsg(m);
		return NULL;
	}
	read_size=0;
	while (read_size<m->pbmsg_len) {
		size_t ret = read(fd,m->pbmsg,m->pbmsg_len);
		if (ret==0 || ret<0) {
			fprintf(stderr,"Something failed in read of TCP socket\n");
			free_pbmsg(m);
			return NULL;
		}
		read_size+=ret;
	}
	return m;	
}

size_t send_fd_pbmsg(int fd, pbmsg * m) {
	size_t ret=0;
	//send the length
	size_t r = write(fd, &m->pbmsg_len, 4);
	r += write(fd, &m->pbmsg_type, 4);
	if (r!=8) {
		fprintf(stderr,"Failed to send_pbmsg write length\n");
		return -1;
	}
	ret+=r;
	//send the payload
	if (m->pbmsg_len>0) {
		r = write(fd, m->pbmsg, m->pbmsg_len);
		if (r!=m->pbmsg_len) {
			fprintf(stderr,"Failed to send message write\n");
			return -1;
		}	
		ret+=r;
	}
	return ret;
}


//some basic file ops
char * read_file(const char *fn, size_t * len) {
	fprintf(stderr,"READING A FILE!, |%s|\n",fn); 
	FILE * fptr = fopen(fn, "rb");
	if (!fptr) {
		fprintf(stderr, "Unable to open file %s", fn);
		return NULL;
	}
	
	fseek(fptr, 0, SEEK_END);
	*len=ftell(fptr);
	fseek(fptr, 0, SEEK_SET);

	char * buffer=(char *)malloc(*len);
	if (!buffer) {
		fprintf(stderr, "Memory error! in read_file");
		fclose(fptr);
		return NULL;
	}
	size_t r = fread(buffer, *len, 1, fptr);
	if (r!=1) {
		fprintf(stderr,"Errror in reading file?\n");
	}
	fclose(fptr);
	return buffer;
}

int write_file(const char *fn , char * buffer, size_t len) {
	//Open file
	FILE *fptr = fopen(fn, "wb");
	if (!fptr) {
		fprintf(stderr, "Unable to open file %s", fn);
		return -1;
	}
	size_t ret = fwrite(buffer, len, 1, fptr);
	fclose(fptr);
	return ret;
}


pbmsg * new_pbmsg_from_file(const char * fn) {
	size_t len=0; 
	char * data = read_file(fn,&len);
	if (data==NULL) {
		fprintf(stderr,"Failed to read file..\n");
		return NULL;
	}
	pbmsg * m = new_pbmsg();
	m->pbmsg_len = len;
	m->pbmsg_type = PBMSG_FILE;
	m->pbmsg = data;
	return m;
}

int pbmsg_to_file(pbmsg *m , const char * fn) {
	int ret = write_file(fn, m->pbmsg, m->pbmsg_len);
	return ret;
}

