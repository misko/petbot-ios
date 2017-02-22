#include "pb.h"
//stun_server stun_servers = {.addrv4="159.203.252.147", .addrv6="", .resolved=0, .hostname = "stun.petbot.ca", .port=3478, .user="misko", .passwd="misko",.next=NULL};
stun_server stun_servers = {.addrv4="", .addrv6="", .resolved=0, .hostname = "", .port=3478, .user="misko", .passwd="misko",.next=NULL};


gchar * get_substring (const gchar *regex, const gchar *string) {
    GRegex *gregex;
    GMatchInfo *match_info = NULL;
    gchar *ret = NULL;
    
    gregex = g_regex_new (regex,
                          G_REGEX_MULTILINE | G_REGEX_NEWLINE_CRLF, 0, NULL);
    g_assert (gregex);
    
    g_regex_match (gregex, string, 0, &match_info);
    
    if (g_match_info_get_match_count (match_info) == 2)
        ret = g_match_info_fetch (match_info, 1);
    
    g_match_info_free (match_info);
    g_regex_unref (gregex);
    
    return ret;
}

#ifndef TARGET_OS_IPHONE

#include <unistd.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <limits.h>
#include <stdio.h>
#include <assert.h>
#include <signal.h>
#include <pwd.h>
#include <pthread.h>

#include <errno.h>

#include <fcntl.h>
#include <unistd.h>

#define IO_BASE_ADDRESS  0x01c00000
#define SID_BASE_ADDRESS 0x01c23800
#define IO_SIZE          0x00300000
#define SID_MMAP_START   ((SID_BASE_ADDRESS >> 12) << 12)

#define SAFECMP(x,y) strncmp(x,y,strlen(y))
 
#include <grp.h>

#include "config.h"

//#define PATH_MAX        4096

static char * pb_id  = NULL;
char * pb_path = NULL;
char * pb_config_path = NULL;
char * pb_config_file_path = NULL;
char * pb_tmp_path = NULL;

char * root_mount_point = "/";

char * selfie_sound_url = "";

float selfie_dog_sensitivity = 0.8;
float selfie_cat_sensitivity = 0.8;
float selfie_pet_sensitivity = 0.8;
float selfie_person_sensitivity = 0.3;
float selfie_mot_sensitivity = 0.8;
int selfie_timeout = 60*60*4; //2000;
int selfie_length = 25;

int pb_led_enable = 1;
int pb_selfie_enable = 1;

int nice_upnp_enable = 1;

int cedar_stream_bitrate = 300000;
int cedar_selfie_bitrate = 1024*1024;
int cedar_max_bitrate = 1024*1024;
int cedar_min_bitrate = 100000;
int cedar_inc_bitrate = 1024;

int pb_color_fx = 0;
int pb_exposure = 0;
int pb_hflip = 0;
int pb_vflip = 0;
int pb_white_balance = 0;

long master_volume = 50; // 0-63

char * version = GITVERSION;

int stddev_multiplier = 5;

float xor_float(float f, char key) {
	float xord = f;
	char * x = (char*)(&xord);
	int i;
	for (i=0; i<sizeof(float); i++ ){
		*x^=key;
		x++;
	}
	//PBPRINTF("FLOAT IN IS %f out is %f\n",f,xord);
	return xord;
}

void * get_next_token(char ** s) {
	char * c = *s;
	char * p = c;
	for(p=c; *p!='\0' && *p!=':'; p++);
	if (*p=='\0') {
		PBPRINTF("Failed to get next token...\n");
		return NULL;
	}
	*p='\0';
	int len_field = atoi(c);
	*p=':';
	c=p+1;//start of field
	char * r = (char*)malloc(sizeof(char)*(len_field+1));
	if (r==NULL) {
		PBPRINTF("Failed to malloc...\n");
		return NULL;
	}
	if (strlen(c)<len_field) {
		PBPRINTF("Failed something in next token..\n");
		return NULL;
	}
	strncpy(r,c,len_field);
	*s=c+len_field+1;
	r[len_field]='\0';
	return r;	
}


//http://stackoverflow.com/questions/2180079/how-can-i-copy-a-file-on-unix-using-c
int cp(const char *to, const char *from)
{
    int fd_to, fd_from;
    char buf[4096];
    ssize_t nread;
    int saved_errno;

    fd_from = open(from, O_RDONLY);
    if (fd_from < 0)
        return -1;

    fd_to = open(to, O_WRONLY | O_CREAT | O_EXCL, 0666);
    if (fd_to < 0)
        goto out_error;

    while (nread = read(fd_from, buf, sizeof buf), nread > 0)
    {
        char *out_ptr = buf;
        ssize_t nwritten;

        do {
            nwritten = write(fd_to, out_ptr, nread);

            if (nwritten >= 0)
            {
                nread -= nwritten;
                out_ptr += nwritten;
            }
            else if (errno != EINTR)
            {
                goto out_error;
            }
        } while (nread > 0);
    }

    if (nread == 0)
    {
        if (close(fd_to) < 0)
        {
            fd_to = -1;
            goto out_error;
        }
        close(fd_from);

        /* Success! */
        return 0;
    }

  out_error:
    saved_errno = errno;

    close(fd_from);
    if (fd_to >= 0)
        close(fd_to);

    errno = saved_errno;
    return -1;
}

void pbchown (const char *file_path,const char *user_name, const char *group_name)  {
  uid_t          uid;
  gid_t          gid;
  struct passwd *pwd;
  struct group  *grp;

  pwd = getpwnam(user_name);
  if (pwd == NULL) {
      PBPRINTF("Failed to get uid");
	return;
  }
  uid = pwd->pw_uid;

  grp = getgrnam(group_name);
  if (grp == NULL) {
      PBPRINTF("Failed to get gid");
	return;
  }
  gid = grp->gr_gid;

  if (chown(file_path, uid, gid) == -1) {
      PBPRINTF("Failed CHOWN");
	return;
  }
}



void pbtouch(char *fn ) {
	PBPRINTF("TOCUHING %p\n",fn);
	FILE * fptr = fopen(fn,"w");
	if (fptr!=NULL) {
		fclose(fptr);
	}
}

/*struct process_guard_helper_s {
   int pipe_from_child;
   int * write_to;
   char * s;
};

void process_guard_helper(void * x) {
	struct process_guard_helper_s * xs = (struct process_guard_helper_s*)x;
	PBPRINTF("HELPER THREAD LOOKING FOR %s %d\n",xs->s,xs->pipe_from_child);	
	int buffer_size = 128;
	char * buffer = (char*)malloc(sizeof(char)*(buffer_size+1));
	if (buffer==NULL) {
		PBPRINTF("FAIL MALLOC\n");
		exit(1);
	}

	//FILE * fptr = fdopen(xs->pipe_from_child,"r");
	//setvbuf(fptr,NULL,_IONBF,0);
	//while(fgets(buffer,buffer_size,fptr)!=NULL) {
	//	PBPRINTF("GOT |%s|\n",buffer);
	//	if (strstr(buffer,xs->s)!=NULL) {
	//		PBPRINTF("FOUND IT!\n");
	//		return;
	//	}
	//}
	//PBPRINTF("FOUND IT!?\n");
	//return; 
	
	size_t i = 0;
	while (1) {
		int r = read(xs->pipe_from_child,buffer+i,buffer_size-i);
		PBPRINTF("GUARD GOT SOMEHING!\n");
		if (r<=0) {
			PBPRINTF("OTHER SIDE CLOSED?\n");
			return;
		}
		i+=r;
		int last_n = -1;
		for (int j=0; j<i; j++) {
			if (buffer[j]=='\n') {
				buffer[j]='\0';
				//PBPRINTF("GUARD HAS |%s| %d %d\n",buffer + (last_n>0 ? last_n : 0),i,j);
				if (strstr(buffer + (last_n>0 ? last_n : 0),xs->s)!=NULL) {
					PBPRINTF("FOUND IT!\n");
					return;
				}
				last_n=j;
			}
		}
		i=i-last_n-1;
		for (int j=0; j<i; j++) {
			buffer[j]=buffer[j+last_n+1];
		}
		PBPRINTF("GUARD HAS %lu\n",i);
	}

}

void process_guard(int pipe_from_child, int * write_to, char * s) {
	pthread_t t;
	struct process_guard_helper_s * xs = (struct process_guard_helper_s*)malloc(sizeof(struct process_guard_helper_s));
	xs->pipe_from_child = pipe_from_child;
	xs->write_to = write_to;
	xs->s = s;
	int ret = pthread_create( &t, NULL, process_guard_helper, xs);
}*/

char * next_tok(char * str, char d) {
	if (str==NULL) {
		return NULL;
	}
	char * x = str;
	while(*x!=d && *x!='\0') {
		x++;
	}
	if (x=='\0') {
		return NULL;
	}
	*x='\0';
	return x+1;
}

void kill_pid(int * pid_t) {
	int pid=*pid_t;
	if (pid<=0) {
		return;
	}
	PBPRINTF("KILLING PID %d\n",pid);
        if (pid<=0) {
                PBPRINTF("NOT KILL @ %d\n",pid);
                return;
        }
        kill(pid, SIGTERM); //TODO make this more reliable?
        if (waitpid(pid,NULL,0)< 0) {
                PBPRINTF("FAILED TO COLLECT ZOMBIE\n");
        } else {
                PBPRINTF("COLLECTED ZOMBIE\n");
        }
}

int file_exists(char * f ) {
	if( access( f, F_OK ) != -1 ) {
		return 0;
	}
	return -1;
}

int mount_rw(char * mp) {
#ifdef OSX
	PBPRINTF("MOUNT READ WRITE %s\n",mp);
#else
        int ret = mount(NULL, mp, NULL , MS_REMOUNT , NULL);
	if (ret!=0) {
        	perror("Error: ");
		return 1;
	}
#endif
	return 0;
}

int mount_ro(char * mp) {
#ifdef OSX
	PBPRINTF("MOUNT READ ONLY %s\n",mp);
#else
        int ret = mount(NULL, mp, NULL , MS_REMOUNT | MS_RDONLY, NULL);
	if (ret!=0) {
        	perror("Error: ");
		return 1;
	}
#endif
	return 0;
}

int mount_config_rw() {
	//return mount_rw(pb_config_path);
	return 0;
}

int mount_config_ro() {
	//return mount_ro(pb_config_path);
	return 0;
}

int mount_root_rw() {
	return mount_rw(root_mount_point);
}

int mount_root_ro() {
	return mount_ro(root_mount_point);
}

void sig_handler_def(int sig) {
    fprintf(stderr,"WTF ?? ZOMBIE??\n");
    kill(0, SIGTERM);
}

void killzombies(void) {
    sig_handler_def(-1);
}

void register_sig_handlers() {
	signal(SIGINT, sig_handler_def);
	signal(SIGKILL, sig_handler_def);
	signal(SIGSEGV, sig_handler_def);
	//signal(SIGTERM, sig_handler_def);
	atexit(killzombies);
	//setpgid(0, 0);
}

char * pbcat(char * a, char * b ) {
	char * c = (char*)malloc(sizeof(char)*(strlen(a)+strlen(b)+1));
	if (c==NULL) {
		PBPRINTF("FAILED TO MALLOC PBCAT\n");
		exit(1);
	}
	sprintf(c,"%s%s",a,b);
	return c;	
}

char *randstring(int length) {    
    static int mySeed = 25011984;
    char *string = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.-#'?!";
    size_t stringLen = strlen(string);        
    char *randomString = NULL;
    srand(time(NULL) * length + ++mySeed);

    if (length < 1) {
        length = 1;
    }

    randomString = malloc(sizeof(char) * (length +1));

    if (randomString) {
        short key = 0;

        for (int n = 0;n < length;n++) {            
            key = rand() % stringLen;          
            randomString[n] = string[key];
        }

        randomString[length] = '\0';

        return randomString;        
    }
    else {
        printf("No memory");
        exit(1);
    }
}

void pbdelay(int d) {
        usleep(1000*d); //on a20 we dont have wiring delay so lets sleep for microseconds
}


#ifdef A20

DeviceSID * getSID() {
  int fd;
  if ((fd = open("/dev/mem", O_RDONLY | O_SYNC)) == -1) {
    return NULL;
  }
  void *io = mmap(0, 4096, PROT_READ, MAP_PRIVATE, fd, SID_MMAP_START);
  if (io == MAP_FAILED) {
    close(fd);
    return NULL;
  }

  DeviceSID * serial = (DeviceSID*)malloc(sizeof(DeviceSID));
  *serial = *(DeviceSID *)(io + (SID_BASE_ADDRESS - SID_MMAP_START));

  if (munmap(io, sizeof(DeviceSID)) == -1) {
    close(fd);
    return NULL;
  }
  close(fd);

  return serial;
}

#else

DeviceSID * getSID() { 
  //srand(time(NULL));
#ifdef OSX
  sranddev();
#endif
#ifdef A20
  sranddev();
#endif
  DeviceSID * serial = (DeviceSID*)malloc(sizeof(DeviceSID));
  serial->key0=2;
  serial->key1=3; 
  serial->key2=5;
  serial->key3=(uint32_t)rand();
  return serial;
}
  

#endif

char * pbID() {
	if (pb_id==NULL) {
		DeviceSID * serial = NULL;
		char * device_id_fn = pbcat(pb_config_path,"/device_id");
		if (file_exists(device_id_fn)==0) {
			//load the file
			FILE * ptr= fopen(device_id_fn,"rb");
			if (!ptr) {
				PBPRINTF("Unable to open file!");
				exit(1);
			}
			serial = (DeviceSID*)malloc(sizeof(DeviceSID));
			if (serial==NULL) {
				PBPRINTF("Failed to malloc serial\n");
				exit(1);
			}
			int ret = fread(serial,sizeof(DeviceSID),1,ptr);
			if (ret!=1) {
				PBPRINTF("FAILED TO READ DEVICE ID\n");
				exit(1);
			}
			fclose(ptr);
		} else {
			//generate or get an ID
			serial = getSID();
#ifndef A20
			//write the file
			FILE * ptr= fopen(device_id_fn,"wb");
			if (!ptr) {
				PBPRINTF("Unable to open file!");
				exit(1);
			}
			int ret = fwrite(serial,sizeof(DeviceSID),1,ptr);
			if (ret!=1) {
				PBPRINTF("FAILED TO WRITE DEVICE ID\n");
				exit(1);
			}
			fclose(ptr);
			
#endif
		}
		
		//ok lets generate the pb_id
		pb_id=(char*)malloc(sizeof(char)*(8*4+3+1));
		if (pb_id==NULL) {
			PBPRINTF("FAILED TO MALLOC PBID\n");
			exit(1);
		}
		sprintf(pb_id,"%08x-%08x-%08x-%08x", serial->key0, serial->key1, serial->key2, serial->key3);
		PBPRINTF("PETBOT ID IS %s\n",pb_id);
	}
	return pb_id;	
}

char * executable_path() {
	if (pb_path!=NULL) {
		return pb_path;
	}
	char path[PATH_MAX];
	char * dest = (char*) malloc(sizeof(char)*(PATH_MAX+1));
	if (dest==NULL) {
		PBPRINTF("FAILED TO MALLOC FO EEX PATH\n");
		exit(1);
	}
	//struct stat info;
	sprintf(path, "/proc/self/exe");
	if (readlink(path, dest, PATH_MAX) == -1)
		perror("readlink");
	else {
		printf("%s\n", dest);
	}
	return dest;
}

char * config(char * key, char * v_str) {
	PBPRINTF("CALLING CONFIG WITH %s %s\n",key,key);
	PBPRINTF("CALLING CONFIG WITH %s %s\n",key,v_str);
	char * r = (char*)malloc(sizeof(char)*128);
	if (r==NULL) {
		PBPRINTF("FAILED TO MALLOC in get config!\n");
		exit(1);
	}
	r[0]='\0';
	if (SAFECMP(key,"selfie_dog_sensitivity")==0) {
		if (v_str!=NULL) 
			selfie_dog_sensitivity = atof(v_str);
		sprintf(r,"%0.4f",selfie_dog_sensitivity);
	} else if (SAFECMP(key,"selfie_cat_sensitivity")==0) {
		if (v_str!=NULL) 
			selfie_cat_sensitivity = atof(v_str);
		sprintf(r,"%0.4f",selfie_cat_sensitivity);
	} else if (SAFECMP(key,"selfie_pet_sensitivity")==0) {
		if (v_str!=NULL) 
			selfie_pet_sensitivity = atof(v_str);
		sprintf(r,"%0.4f",selfie_pet_sensitivity);
	} else if (SAFECMP(key,"selfie_mot_sensitivity")==0) {
		if (v_str!=NULL) 
			selfie_mot_sensitivity = atof(v_str);
		sprintf(r,"%0.4f",selfie_mot_sensitivity);
	} else if (SAFECMP(key,"selfie_sound_url")==0) {
		free(r);
		if (v_str!=NULL) 
			selfie_sound_url=strdup(v_str);
		r = strdup(selfie_sound_url);
	} else if (SAFECMP(key,"stddev_multiplier")==0) {
		if (v_str!=NULL) 
			stddev_multiplier = atoi(v_str);
		sprintf(r,"%d",stddev_multiplier);
	} else if (SAFECMP(key,"selfie_timeout")==0) {
		if (v_str!=NULL) 
			selfie_timeout = atoi(v_str);
		sprintf(r,"%d",selfie_timeout);
	} else if (SAFECMP(key,"selfie_length")==0) {
		if (v_str!=NULL) 
			selfie_length = atoi(v_str);
		sprintf(r,"%d",selfie_length);
	} else if (SAFECMP(key,"master_volume")==0) {
		if (v_str!=NULL) 
			master_volume = atoi(v_str);
		sprintf(r,"%ld",master_volume);
	} else if (SAFECMP(key,"pb_color_fx")==0) {
		if (v_str!=NULL) 
			pb_color_fx = atoi(v_str);
		sprintf(r,"%d",pb_color_fx);
	} else if (SAFECMP(key,"pb_exposure")==0) {
		if (v_str!=NULL) 
			pb_exposure = atoi(v_str);
		sprintf(r,"%d",pb_exposure);
	} else if (SAFECMP(key,"pb_hflip")==0) {
		if (v_str!=NULL) 
			pb_hflip = atoi(v_str);
		sprintf(r,"%d",pb_hflip);
	} else if (SAFECMP(key,"pb_vflip")==0) {
		if (v_str!=NULL) 
			pb_vflip = atoi(v_str);
		sprintf(r,"%d",pb_vflip);
	} else if (SAFECMP(key,"pb_white_balance")==0) {
		if (v_str!=NULL) 
			pb_white_balance = atoi(v_str);
		sprintf(r,"%d",pb_white_balance);
	} else if (SAFECMP(key,"pb_selfie_enable")==0) {
		if (v_str!=NULL) 
			pb_selfie_enable = atoi(v_str);
		sprintf(r,"%d",pb_selfie_enable);
	} else if (SAFECMP(key,"pb_led_enable")==0) {
		if (v_str!=NULL) 
			pb_led_enable = atoi(v_str);
		sprintf(r,"%d",pb_led_enable);
	} else if (SAFECMP(key,"nice_upnp_enable")==0) {
		if (v_str!=NULL) 
			nice_upnp_enable = atoi(v_str);
		sprintf(r,"%d",nice_upnp_enable);
	} else if (SAFECMP(key,"cedar_stream_bitrate")==0) {
		if (v_str!=NULL) 
			cedar_stream_bitrate = atoi(v_str);
		sprintf(r,"%d",cedar_stream_bitrate);
	} else if (SAFECMP(key,"cedar_selfie_bitrate")==0) {
		if (v_str!=NULL) 
			cedar_selfie_bitrate = atoi(v_str);
		sprintf(r,"%d",cedar_selfie_bitrate);
	} else if (SAFECMP(key,"cedar_max_bitrate")==0) {
		if (v_str!=NULL) 
			cedar_max_bitrate = atoi(v_str);
		sprintf(r,"%d",cedar_max_bitrate);
	} else if (SAFECMP(key,"cedar_min_bitrate")==0) {
		if (v_str!=NULL) 
			cedar_min_bitrate = atoi(v_str);
		sprintf(r,"%d",cedar_min_bitrate);
	} else if (SAFECMP(key,"cedar_inc_bitrate")==0) {
		if (v_str!=NULL) 
			cedar_inc_bitrate = atoi(v_str);
		sprintf(r,"%d",cedar_inc_bitrate);
	} else {
		free(r);
		return NULL;
	} 
	return r;
}

char * get_config(char * key) {
	return config(key,NULL);
}

char * set_config(char * key, char * v_str) {
	return config(key,v_str);
}

void pb_config_read() {
	char * buffer =  pb_readFile(pb_config_file_path);
	if (buffer!=NULL) {
		char * p = buffer;
		while(p) {
			char * c = strchr(p, '\n');
			if (c) *c = '\0';  // temporarily terminate the current line
			char * pt = p;
			while (*pt!='\0' && *pt!='\n' && *pt!='\t') {pt++;};
			if (*pt=='\t') {
				*pt='\0';
				pt++;
				char * key = p;
				char * value = pt;
				if (strlen(value)>0) {
					set_config(key,value);
					//printf("curLine=[%s | %s | %f]\n", p,pt,selfie_dog_sensitivity);
				}
			}
			
			p = c ? (c+1) : NULL;
		}	
		free(buffer);
	}
}

void pb_config_write() {
	size_t max_file_size = 1024*32;
	char * buffer = (char*)malloc(sizeof(char)*max_file_size);
	if (buffer==NULL) {
		PBPRINTF("FAILED TO MALLOC FOR CONFIG WRITE\n");
		exit(1);
	}	
	buffer[0]='\0';
	size_t offset = 0;
	char * s;
	s=get_config("selfie_dog_sensitivity");
	offset+=sprintf(buffer+offset, "selfie_dog_sensitivity\t%s\n", s);
	free(s);
	s=get_config("selfie_cat_sensitivity");
	offset+=sprintf(buffer+offset, "selfie_cat_sensitivity\t%s\n", s);
	free(s);
	s=get_config("selfie_pet_sensitivity");
	offset+=sprintf(buffer+offset, "selfie_pet_sensitivity\t%s\n", s);
	free(s);
	s=get_config("selfie_mot_sensitivity");
	offset+=sprintf(buffer+offset, "selfie_mot_sensitivity\t%s\n", s);
	free(s);
	s=get_config("stddev_multiplier");
	offset+=sprintf(buffer+offset, "stddev_multiplier\t%s\n", s);
	free(s);
	s=get_config("selfie_timeout");
	offset+=sprintf(buffer+offset, "selfie_timeout\t%s\n", s);
	free(s);
	s=get_config("selfie_length");
	offset+=sprintf(buffer+offset, "selfie_length\t%s\n", s);
	free(s);

	s=get_config("selfie_sound_url");
	offset+=sprintf(buffer+offset, "selfie_sound_url\t%s\n", s);
	free(s);

	s=get_config("master_volume");
	offset+=sprintf(buffer+offset, "master_volume\t%s\n", s);
	free(s);
	s=get_config("pb_color_fx");
	offset+=sprintf(buffer+offset, "pb_color_fx\t%s\n", s);
	free(s);
	s=get_config("pb_exposure");
	offset+=sprintf(buffer+offset, "pb_exposure\t%s\n", s);
	free(s);
	s=get_config("pb_hflip");
	offset+=sprintf(buffer+offset, "pb_hflip\t%s\n", s);
	free(s);
	s=get_config("pb_vflip");
	offset+=sprintf(buffer+offset, "pb_vflip\t%s\n", s);
	free(s);
	s=get_config("pb_white_balance");
	offset+=sprintf(buffer+offset, "pb_white_balance\t%s\n", s);
	free(s);

	s=get_config("pb_selfie_enable");
	offset+=sprintf(buffer+offset, "pb_selfie_enable\t%s\n", s);
	free(s);
	s=get_config("pb_led_enable");
	offset+=sprintf(buffer+offset, "pb_led_enable\t%s\n", s);
	free(s);

	s=get_config("nice_upnp_enable");
	offset+=sprintf(buffer+offset, "nice_upnp_enable\t%s\n", s);
	free(s);

	s=get_config("cedar_stream_bitrate");
	offset+=sprintf(buffer+offset, "cedar_stream_bitrate\t%s\n", s);
	free(s);
	s=get_config("cedar_selfie_bitrate");
	offset+=sprintf(buffer+offset, "cedar_selfie_bitrate\t%s\n", s);
	free(s);
	s=get_config("cedar_max_bitrate");
	offset+=sprintf(buffer+offset, "cedar_max_bitrate\t%s\n", s);
	free(s);
	s=get_config("cedar_min_bitrate");
	offset+=sprintf(buffer+offset, "cedar_min_bitrate\t%s\n", s);
	free(s);
	s=get_config("cedar_inc_bitrate");
	offset+=sprintf(buffer+offset, "cedar_inc_bitrate\t%s\n", s);
	free(s);

	offset+=sprintf(buffer+offset, "VERSION\t%s\n", version);
	if (pb_config_file_path!=NULL) {
		pb_writeFile(pb_config_file_path, buffer, strlen(buffer));
	}
	free(buffer);
}

char * pb_writeFile(char * fn, void * d, size_t sz) {
   FILE *fptr = fopen(fn, "w");
   if (fptr) {
	fwrite(d,sz,1,fptr);
   } else {
	PBPRINTF("FAiled to open file for writting\n");
	return NULL;
   }
   fclose(fptr);
   return fn;
}

//http://stackoverflow.com/questions/3463426/in-c-how-should-i-read-a-text-file-and-print-all-strings
char * pb_readFile(char * fn) {
   char *buffer = NULL;
   int string_size, read_size;
   FILE *fptr = fopen(fn, "r");
   if (fptr) {
       // Seek the last byte of the file
       fseek(fptr, 0, SEEK_END);
       // Offset from the first to the last byte, or in other words, filesize
       string_size = ftell(fptr);
       // go back to the start of the file
       rewind(fptr);
       // Allocate a string that can hold it all
       buffer = (char*) malloc(sizeof(char) * (string_size + 1) );
       // Read it all in one operation
       read_size = fread(buffer, sizeof(char), string_size, fptr);
       // fread doesn't set it so put a \0 in the last position
       // and buffer is now officially a string
       buffer[string_size] = '\0';
       if (string_size != read_size) {
           // Something went wrong, throw away the memory and set
           // the buffer to NULL
           free(buffer);
           buffer = NULL;
       }
       // Always remember to close the file.
       fclose(fptr);
    }

    return buffer;
}

char * pb_rewrite(char * config, char * output_fn, char ** keys, char ** values, int n) {
	char * config_contents = pb_readFile(config);
	if (config_contents==NULL) {
		PBPRINTF("Failed to read a configuraiton file\n");
		return NULL;
	}
	for (int i =0; i<n; i++) {
		size_t c = 0;
		char * p_ptr = strstr(config_contents+c,keys[i]);
		while (p_ptr!=NULL) {
			size_t new_size = strlen(config_contents) - strlen(keys[i]) + strlen(values[i]) +1; 
			char * config_contents_new = (char*)malloc(sizeof(char)*new_size);
			size_t p = p_ptr - config_contents;
			strncpy(config_contents_new,config_contents,p); //copy the first chunk
			strcpy(config_contents_new+p,values[i]); // copy in the key
			strncpy(config_contents_new+p+strlen(values[i]),config_contents+p+strlen(keys[i]),strlen(config_contents)-p-strlen(keys[i])); //copy the rest
			config_contents_new[new_size-1]='\0';
			c = (p+1+strlen(values[i]))-strlen(keys[i]);
			free(config_contents);
			config_contents=config_contents_new;
			p_ptr = strstr(config_contents+c,keys[i]);
		}
	}	
	
	pb_writeFile(output_fn,config_contents,strlen(config_contents));
	free(config_contents);
	return output_fn;
}


pb_log * pb_log_new(size_t sz) {
	pb_log * pl = (pb_log * )malloc(sizeof(pb_log));
	if (pl==NULL) {
		PBPRINTF("FAILED TO ALLOCATE NEW LOG :(\n");
		return NULL;
	}
	memset(pl,0,sizeof(pb_log));
	char * log = (char*)malloc(sizeof(char)*sz);
	if (log==NULL) {
		free(pl);
		return NULL;
	}
	log[0]='\0';
	pl->log=log;
	pl->log_used=0;
	pl->log_len=sz;
	return pl;
}

gboolean pb_log_add(pb_log* pl, char * s) {

}

gboolean pb_log_pop(pb_log* pl, size_t sz) {

}

#endif
