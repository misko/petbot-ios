
#ifdef A20
#endif

#ifdef OSX
#endif


//#define PBPRINTF(fmt, args...)    fprintf(stderr, fmt, ## args)
#define PBPRINTF(fmt, args...) fprintf(stderr, "DEBUG: %s:%d:%s(): " fmt, \
    __FILE__, __LINE__, __func__, ##args)

void pbdelay(int d);


