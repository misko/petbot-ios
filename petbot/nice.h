#ifndef NICE_H 
#define NICE_H 1
#include <agent.h>
#include <tcp_utils.h>

extern guint stream_id;
extern NiceAgent *agent;

char * our_nice_string(int controlling);
void start_nice(pbsock * pbs);
#endif
