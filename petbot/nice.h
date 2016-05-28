#ifndef NICE_H 
#define NICE_H 1
#include <agent.h>
#include <tcp_utils.h>

extern guint stream_id;
extern NiceAgent *agent;

char * our_nice_string(int controlling);
void start_nice(pbsock * pbs);

int start_nice_server(pbsock *pbs, pbmsg * ice_request);
int start_nice_client(pbsock *pbs);
GThread *  start_nice_thread();
pbmsg * make_ice_request();
GThread *  start_nice_thread();
int recvd_ice_response(pbmsg * m);

#endif
