#ifndef NICE_H 
#define NICE_H 1
#include <agent.h>
#include <tcp_utils.h>

extern guint stream_id;
extern NiceAgent *agent;

char * our_nice_string(int controlling);
void start_nice(pbsock * pbs);

char * start_nice_server_get_nice(int * to_child, int * from_child);
int start_nice_server_with_nice(int *to_child, int * from_child, pbmsg * ice_request, char * our_nice);
int start_nice_server(pbsock *pbs, pbmsg * ice_request);
int start_nice_client(pbsock *pbs);
GThread * start_nice_thread(int controlling, int * from_child, int * to_child);
pbmsg * make_ice_request();
int recvd_ice_response(pbmsg * ice_response, int * from_child, int * to_child);
#endif
