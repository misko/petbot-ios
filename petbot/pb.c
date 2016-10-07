#include <unistd.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <limits.h>
#include <stdio.h>
#include <assert.h>
#include <signal.h>
#include <sys/types.h>
#include <pwd.h>
#include <pthread.h>

#include <sys/mount.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/mman.h>

#include <time.h>
#include <stdlib.h>

#define IO_BASE_ADDRESS  0x01c00000
#define SID_BASE_ADDRESS 0x01c23800
#define IO_SIZE          0x00300000
#define SID_MMAP_START   ((SID_BASE_ADDRESS >> 12) << 12)
 
typedef struct DeviceSID {
  uint32_t key0;
  uint32_t key1;
  uint32_t key2;
  uint32_t key3;
} DeviceSID;

#include <grp.h>

#include "pb.h"

//#define PATH_MAX        4096

static char * pb_id  = NULL;
char * pb_path = NULL;
char * pb_config_path = NULL;
char * pb_tmp_path = NULL;

char * root_mount_point = "/";

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
	FILE * fptr = fopen(fn,"w");
	fclose(fptr);
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
        kill(pid, SIGINT); //TODO make this more reliable?
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
  sranddev();
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
