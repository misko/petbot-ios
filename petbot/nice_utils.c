/*
 * Copyright 2013 University of Chicago
 *  Contact: Bryce Allen
 * Copyright 2013 Collabora Ltd.
 *  Contact: Youness Alaoui
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * Alternatively, the contents of this file may be used under the terms of the
 * the GNU Lesser General Public License Version 2.1 (the "LGPL"), in which
 * case the provisions of LGPL are applicable instead of those above. If you
 * wish to allow use of your version of this file only under the terms of the
 * LGPL and not to allow others to use your version of this file under the
 * MPL, indicate your decision by deleting the provisions above and replace
 * them with the notice and other provisions required by the LGPL. If you do
 * not delete the provisions above, a recipient may use your version of this
 * file under either the MPL or the LGPL.
 */

/*
 * Example using libnice to negotiate a UDP connection between two clients,
 * possibly on the same network or behind different NATs and/or stateful
 * firewalls.
 *
 * Build:
 *   gcc -o simple-example simple-example.c `pkg-config --cflags --libs nice`
 *
 * Run two clients, one controlling and one controlled:
 *   simple-example 0 $(host -4 -t A stun.stunprotocol.org | awk '{ print $4 }')
 *   simple-example 1 $(host -4 -t A stun.stunprotocol.org | awk '{ print $4 }')
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "tcp_utils.h"
#include <assert.h>
#include <semaphore.h>
#include <unistd.h>
#include <gst/gst.h>
#include <gst/video/video.h>
#ifdef TARGET_OS_IPHONE
#include <agent.h>
#else
#include <nice/agent.h>
#endif

#include "pb.h"

//sem_t negotiation_done;

//static gboolean negotiation_done;
//static GCond negotiate_cond;
//static GMutex negotiate_mutex;
//static GMainLoop *gloop;
//static GIOChannel* gpipe;
//guint stream_id;
//NiceAgent *agent;

static const gchar *candidate_type_name[] = {"host", "srflx", "prflx", "relay"};

static const gchar *state_name[] = {"disconnected", "gathering", "connecting",
                                    "connected", "ready", "failed"};

static char * str_local_data(NiceAgent *agent, guint stream_id,
    guint component_id);
static int parse_remote_data(NiceAgent *agent, guint stream_id,
    guint component_id, char *line);
static void cb_candidate_gathering_done(NiceAgent *agent, guint stream_id,
    gpointer data);
static void cb_new_selected_pair(NiceAgent *agent, guint stream_id,
    guint component_id, gchar *lfoundation,
    gchar *rfoundation, gpointer data);
static void cb_component_state_changed(NiceAgent *agent, guint stream_id,
    guint component_id, guint state,
    gpointer data);
static void cb_nice_recv(NiceAgent *agent, guint stream_id, guint component_id,
    guint len, gchar *buf, gpointer data);
static gboolean pipein_remote_info_cb (GIOChannel *source, GIOCondition cond,
    gpointer data);
NiceAgent * init_ice(pb_nice_io * pbnio);

//gchar * stun_addr = "stun.stunprotocol.org";
//gchar * stun_addr = "159.203.252.147";
//gchar * stun_addr = "petbot.ca";
//guint stun_port = 3478;

//guint pipe_to_parent, pipe_from_parent;


//GThread *  start_nice_thread(int controlling, int * from_child, int * to_child);
	
//int to_child[2];
//int from_child[2];
//GThread * ice_thread;
//int help_params[4];

/*void * start_ice_helper(void * x) {
	int * params = (int*)x;
	int controlling = params[0];
	int to_parent = params[1];
	int from_parent = params[2];
	init_ice(controlling, to_parent, from_parent);
	//free(params); //mem leak
    return NULL;
}*/

/*char * start_nice_server_get_nice(int * to_child, int * from_child) {
	//(1) get our nice 
	//(2) send it back
	//(3) negotiate
	//PBPRINTF("Starting nice server\n");
	//start_nice_thread(1,from_child,to_child);
	//pass parameters in an array
        init_ice(1, from_child[1], to_child[0]);
	//get our string from the child thread
	pbmsg * m = recv_fd_pbmsg(from_child[0]);
	char * our_nice = strdup(m->pbmsg);
	//mem leak free m
	return our_nice;
}*/
//int start_nice_server_with_nice(int *to_child, int * from_child, pbmsg * ice_request, char * our_nice) {
int start_nice_server_with_nice(pb_nice_io * pbnio) {

	//we started with the other nice lets negotiate
	//char * other_nice = ice_request->pbmsg;	

	PBPRINTF("Our nice string, %s\n",pbnio->our_nice);
	PBPRINTF("Other nice string %s\n",pbnio->other_nice);
	
	pbmsg * m = new_pbmsg_from_str(pbnio->other_nice);
	send_fd_pbmsg(pbnio->pipe_to_child,m);

    	PBPRINTF("WAIT ON COND");
	g_mutex_lock(&(pbnio->negotiate_mutex));
	while (!(pbnio->negotiation_done))
		g_cond_wait(&(pbnio->negotiate_cond), &(pbnio->negotiate_mutex));
	g_mutex_unlock(&(pbnio->negotiate_mutex));
        PBPRINTF("Returning from start ICE, everything went ok?\n");
	return 0;
}
/*
int start_nice_server(pbsock *pbs, pbmsg * ice_request) {
	assert(pbs!=NULL);
	int to_child[2];
	int from_child[2];
	if (pipe(to_child)!=0 || pipe(from_child)!=0) {
		perror("pipe");
		PBPRINTF("Failed to make pipes for children\n");
		exit(1);
	}

	assert((ice_request->pbmsg_type ^ (PBMSG_ICE | PBMSG_REQUEST | PBMSG_STRING)) == 0);
	char * our_nice = start_nice_server_get_nice(to_child, from_child);
	//Send message to the other side
	pbmsg * ice_response = new_pbmsg_from_str(our_nice);
	ice_response->pbmsg_type= PBMSG_ICE | PBMSG_CLIENT | PBMSG_RESPONSE | PBMSG_SUCCESS | PBMSG_STRING;
	send_pbmsg(pbs, ice_response);
	PBPRINTF("Starting nice server - sent request\n");
	return start_nice_server_with_nice(to_child,from_child,ice_request,our_nice);
}*/


/*GThread *  start_nice_thread(int controlling, int * from_child, int * to_child) {
	//(1)
	//make pipes	
	//pass parameters in an array
	int * help_params = (int*)malloc(sizeof(int)*4);
	if (help_params==NULL) {
		PBPRINTF("Failed to malloc help params\n");
		return NULL;
	}
	help_params[0]=controlling; // 0 for client, 1 for server
	help_params[1]=from_child[1];
	help_params[2]=to_child[0];
	return  g_thread_new("ice thread", &start_ice_helper, help_params);
}*/

pbmsg * make_ice_request(int * from_child, int * to_child) { // must be called only once after start_ice_thread
	//get our string from the child thread
	PBPRINTF("Waiting for our nice...\n");
	pbmsg * m = recv_fd_pbmsg(from_child[0]);
	char * our_nice = strdup(m->pbmsg);
	PBPRINTF("Waiting for our nice...- %s\n",our_nice);
	free_pbmsg(m);
	
	//(2)
	//Send message to the other side
	pbmsg * ice_request = new_pbmsg_from_str(our_nice);
	ice_request->pbmsg_type= PBMSG_ICE | PBMSG_REQUEST | PBMSG_STRING;
	return ice_request;
	PBPRINTF("Waiting for our nice...-sent our nice\n");
}

pb_nice_io * new_pbnio(void) {
    pb_nice_io * pbnio = (pb_nice_io*)malloc(sizeof(pb_nice_io));
    if (pbnio==NULL){
        PBPRINTF("FAILED MALLOC!!!\n");
        exit(1);
    }
    memset(pbnio,0,sizeof(pb_nice_io));
    g_cond_init(&(pbnio->negotiate_cond));
    g_mutex_init(&(pbnio->negotiate_mutex));
    return pbnio;
}

//int recvd_ice_response(pbmsg * ice_response, int * from_child, int * to_child) {
int recvd_ice_response(pbmsg * ice_response, pb_nice_io * pbnio) {
	assert((ice_response->pbmsg_type ^ (PBMSG_ICE | PBMSG_CLIENT | PBMSG_RESPONSE | PBMSG_SUCCESS | PBMSG_STRING)) == 0) ;
        PBPRINTF("RECVD ice response sending it to the thread\n");
	//send_fd_pbmsg(to_child[1],ice_response);
	send_fd_pbmsg(pbnio->pipe_to_child,ice_response);
	//PBPRINTF("Waiting for negotiation to finish\n");
	
	/* dont wait for this try to continue */
    	PBPRINTF("WAIT ON COND");
	
	g_mutex_lock(&(pbnio->negotiate_mutex));
	while (!(pbnio->negotiation_done))
		g_cond_wait(&(pbnio->negotiate_cond), &(pbnio->negotiate_mutex));
	g_mutex_unlock(&(pbnio->negotiate_mutex));
        PBPRINTF("Returning from start ICE, everything went ok?\n");
	return 0;
}
/*
int start_nice_client(pbsock *pbs) {
	//(1) get ice string
	//(2) send ice string to server in ICE REQUEST
	//(3) wait for ice response from server 
	//(4) negotiate ICE

	//(1)
	//make pipes	
	int to_child[2];
	int from_child[2];
	if (pipe(to_child)!=0 || pipe(from_child)!=0) {
		perror("pipe");
		PBPRINTF("Failed to make pipes for children\n");
		exit(1);
	}
	
	PBPRINTF("Starting nice client\n");
	start_nice_thread(0,from_child,to_child);

	pbmsg * ice_request = make_ice_request(from_child, to_child);
	PBPRINTF("Starting nice client - sent request\n");
	send_pbmsg(pbs, ice_request);
	free_pbmsg(ice_request);
	
	//(3)
	PBPRINTF("Starting nice client - wait response\n");
	pbmsg * ice_response = recv_pbmsg(pbs);
	//SUCCESS,RESPONSE,ICE,CLIENT,STRING
	while ((ice_response->pbmsg_type ^ (PBMSG_ICE | PBMSG_CLIENT | PBMSG_RESPONSE | PBMSG_SUCCESS | PBMSG_STRING)) != 0) {
		PBPRINTF("Got a response from server that was unexpected... try again?, %s %x\n",pbmsg_type_to_string(ice_response), ice_response->pbmsg_type);
 		if ((ice_response->pbmsg_type & PBMSG_STRING) !=0) {
		PBPRINTF("Got a response from server that was unexpected... try again ? - %s\n",ice_response->pbmsg);
		}
		ice_response = recv_pbmsg(pbs);
	}
	PBPRINTF("Starting nice client - wait response 2\n");
	int ret = recvd_ice_response(ice_response,from_child,to_child);
	PBPRINTF("Starting nice client - recvd response\n");
	return ret;
}*/
/*
void start_nice(pbsock * pbs) {
	char * our_nice, * other_nice;
	// (1) connect and figure out order
	// (2) contrlling gets a NICE string
	// (3) sends nice string
	// (4) other side generates nice stsring sends back

	//controlling 0 sends nice str to other side
	//controlling 1 recv nice str and starts stuff

	pbmsg *m = recv_pbmsg(pbs); // new client welcome -- this is us
	m = recv_pbmsg(pbs); // new client welcome -- this is either welcome of other user, or other user posting he heard us
	int controlling = 1;
	if (strcmp(m->pbmsg,bb_new_user)==0) {
		free_pbmsg(m);
		m = new_pbmsg_from_str("sorry youre not the first one here");
		send_pbmsg(pbs,m);
		controlling = 0; 
	}
	free_pbmsg(m);

	//make pipes	
	int to_child[2];
	int from_child[2];
	if (pipe(to_child)!=0 || pipe(from_child)!=0) {
		perror("pipe");
		PBPRINTF("Failed to make pipes for children\n");
		exit(1);
	}

	//make ice thread

	//assert(sizeof(int)==sizeof(GMainContext*));
	
	PBPRINTF("Starting nice client\n");
	start_nice_thread(controlling,from_child,to_child);

	m = recv_fd_pbmsg(from_child[0]);
	our_nice = strdup(m->pbmsg);
	//Send message to the other side
	send_pbmsg(pbs, m);
	pbmsg * mm = recv_pbmsg(pbs);
	other_nice = strdup(mm->pbmsg);
	free_pbmsg(mm);
        free_pbmsg(m);

	PBPRINTF("Our nice string, %s\n",our_nice);
	PBPRINTF("Other nice string %s\n",other_nice);
	
	m = new_pbmsg_from_str(other_nice);
	send_fd_pbmsg(to_child[1],m);
	free_pbmsg(m);

	//PBPRINTF("Waiting for negotiation to finish\n");

	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	PBPRINTF("WAIT ON NEGOTIATE MUTEX!!!!!!!\n");	
	g_mutex_lock(&negotiate_mutex);
	while (!negotiation_done)
		g_cond_wait(&negotiate_cond, &negotiate_mutex);
	g_mutex_unlock(&negotiate_mutex);
        PBPRINTF("Returning from start ICE, everything went ok?\n");
	//sem_wait(&negotiation_done);
	//PBPRINTF("Waiting for negotiation to finish - Done - %p\n",agent);
}*/

//NiceAgent * init_ice(int controlling, int to_parent, int from_parent) {
NiceAgent * init_ice(pb_nice_io * pbnio) {
  PBPRINTF("Called init_ice\n");
  //pbnio->pipe_to_parent=to_parent;
  //pbnio->pipe_from_parent=from_parent;
  //pipe_to_parent = to_parent;
  //pipe_from_parent = from_parent;
  if (pbnio->controlling != 0 && pbnio->controlling != 1) {
    PBPRINTF( "controlling must be 1 or 0\n");
    exit(1);
  }

  PBPRINTF("Using stun server '[%s]:%u'\n", stun_addr, stun_port);

  //g_type_init();

  //gloop = g_main_loop_new(NULL, FALSE);
  //GIOChannel * gpipe =  g_io_channel_unix_new(from_parent);
  pbnio->gpipe =  g_io_channel_unix_new(pbnio->pipe_from_parent);
  //io_stdin = g_io_channel_unix_new(fileno(stdin));

  // Create the nice agent
  pbnio->agent = nice_agent_new(NULL,
      NICE_COMPATIBILITY_RFC5245);
  if (pbnio->agent == NULL) {
    g_error("Failed to create agent");
    PBPRINTF("FAILED TO CREATE NICE AGENT!\n");
  }
  

  // Set the STUN settings and controlling mode
  if (stun_addr) {
    g_object_set(pbnio->agent, "stun-server", stun_addr, NULL);
    g_object_set(pbnio->agent, "stun-server-port", stun_port, NULL);
  }
  g_object_set(pbnio->agent, "controlling-mode", pbnio->controlling, NULL);

  // Connect to the signals
  g_signal_connect(pbnio->agent, "candidate-gathering-done",
      G_CALLBACK(cb_candidate_gathering_done), pbnio);
  g_signal_connect(pbnio->agent, "new-selected-pair",
      G_CALLBACK(cb_new_selected_pair), NULL);
  g_signal_connect(pbnio->agent, "component-state-changed",
      G_CALLBACK(cb_component_state_changed), pbnio);

  // Create a new stream with one component
  pbnio->stream_id = nice_agent_add_stream(pbnio->agent, 1);
  if (pbnio->stream_id == 0)
    g_error("Failed to add stream");

  gboolean ret = nice_agent_set_relay_info(pbnio->agent,pbnio->stream_id,1,stun_addr, stun_port, stun_user, stun_passwd,NICE_RELAY_TYPE_TURN_UDP);
  if (ret==FALSE) {
    PBPRINTF("Failed to set the TURN RELAY!\n");
  }

  // Attach to the component to receive the data
  // Without this call, candidates cannot be gathered
  ret = nice_agent_attach_recv(pbnio->agent, pbnio->stream_id, 1, NULL, cb_nice_recv, NULL);
  //ret = nice_agent_attach_recv(agent, stream_id, 1, NULL, NULL, NULL);
  if (ret==FALSE) {
     PBPRINTF("Failed to attach the component to the NICE agent\n");
  }

  // Start gathering local candidates
  if (!nice_agent_gather_candidates(pbnio->agent, pbnio->stream_id)) {
    g_error("Failed to start candidate gathering");
    PBPRINTF("Failed to start candidate gathering\n");
  }

  //g_debug("waiting for candidate-gathering-done signal...");

  PBPRINTF("waiting for candidate-gathering-done signal...");

  // Run the mainloop. Everything else will happen asynchronously
  // when the candidates are done gathering.
  //g_io_channel_unref (io_stdin);

  return pbnio->agent;
}


static void
cb_candidate_gathering_done(NiceAgent *agent, guint _stream_id,
    gpointer data)
{
  PBPRINTF("SIGNAL candidate gathering done\n");

  gchar * sdp = nice_agent_generate_local_sdp (agent);
  PBPRINTF("SDP\n%s\n",sdp);

  pb_nice_io * pbnio = data;
  //GIOChannel* gpipe  = data;
  // Candidate gathering is done. Send our local candidates over pbmsg
  char * s = str_local_data(agent, _stream_id, 1);
  pbmsg * m = new_pbmsg_from_str(s);
  send_fd_pbmsg(pbnio->pipe_to_parent, m);
  free_pbmsg(m); 

  //wait to hear response from the other side over pbmsg?
  g_io_add_watch(pbnio->gpipe, G_IO_IN, pipein_remote_info_cb, pbnio);
}

static gboolean
pipein_remote_info_cb (GIOChannel *source, GIOCondition cond,
    gpointer data)
{
  pb_nice_io * pbnio = data;
  //NiceAgent *agent = pbnio->agent;
  //gchar *line = NULL;
  int rval;

  //there is data waiting lets read it and see if its the right data?
  pbmsg * m = recv_fd_pbmsg(pbnio->pipe_from_parent);

  PBPRINTF( "Remote info is %s\n",m->pbmsg);
  rval = parse_remote_data(pbnio->agent, pbnio->stream_id, 1, m->pbmsg);
  gboolean ret = TRUE;
  if (rval == EXIT_SUCCESS) {
   ret = FALSE;
  } else {
   PBPRINTF("SOMETHING WENT WRONG IN PARSING REMOTE LIBNIC STRING!\n");
  }
  return ret; //ret==FALSE -> stop listening?
}

static void
cb_component_state_changed(NiceAgent *agent, guint _stream_id,
    guint component_id, guint state,
    gpointer data) {
  
  pb_nice_io * pbnio = data;

  PBPRINTF("SIGNAL: state changedXX %d %d %s[%d]\n",
      _stream_id, component_id, state_name[state], state);

  //if (state == NICE_COMPONENT_STATE_READY) {
  if (state == NICE_COMPONENT_STATE_READY || state == NICE_COMPONENT_STATE_CONNECTED) {
    NiceCandidate *local, *remote;

    // Get current selected candidate pair and print IP address used
    if (nice_agent_get_selected_pair (agent, _stream_id, component_id,
                &local, &remote)) {
      gchar ipaddr[INET6_ADDRSTRLEN];

      nice_address_to_string(&local->addr, ipaddr);
      printf("\nNegotiation complete: ([%s]:%d,",
          ipaddr, nice_address_get_port(&local->addr));
      nice_address_to_string(&remote->addr, ipaddr);
      printf(" [%s]:%d)\n", ipaddr, nice_address_get_port(&remote->addr));
    }

    g_mutex_lock(&(pbnio->negotiate_mutex));
    pbnio->negotiation_done = TRUE;
    g_cond_signal(&(pbnio->negotiate_cond));
    g_mutex_unlock(&(pbnio->negotiate_mutex));

    //sem_post(&negotiation_done);
  } else if (state == NICE_COMPONENT_STATE_FAILED) {
    //sem_post(&negotiation_done);
    PBPRINTF("Something failed a ICE negotiation crapped out!\n");
    g_mutex_lock(&(pbnio->negotiate_mutex));
    pbnio->negotiation_done = TRUE;
    g_cond_signal(&(pbnio->negotiate_cond));
    g_mutex_unlock(&(pbnio->negotiate_mutex));
    //g_main_loop_quit (gloop);
    agent=NULL;
  } else if (state==NICE_COMPONENT_STATE_CONNECTING) {
      fprintf(stderr,"NICE CONNECTING\n");
  } else if (state==NICE_COMPONENT_STATE_DISCONNECTED) {
    fprintf(stderr,"NICE DISCONNECTED\n");
  } else if (state==NICE_COMPONENT_STATE_GATHERING) {
      fprintf(stderr,"NICE GATHER\n");
  } else {
      PBPRINTF("WEIRD STATE CHANGE??? WTF\n");
  }
}

static void
cb_new_selected_pair(NiceAgent *agent, guint _stream_id,
    guint component_id, gchar *lfoundation,
    gchar *rfoundation, gpointer data)
{
  PBPRINTF("SIGNAL: selected pair %s %s\n", lfoundation, rfoundation);
}


//without setting even an empty call back things break....
static void
cb_nice_recv(NiceAgent *agent, guint _stream_id, guint component_id,
    guint len, gchar *buf, gpointer data)
{
  //if (len == 1 && buf[0] == '\0')
    //g_main_loop_quit (gloop);
  //printf("%.*s", len, buf);
  //fflush(stdout);
}

static NiceCandidate *
parse_candidate(char *scand, guint _stream_id)
{
  NiceCandidate *cand = NULL;
  NiceCandidateType ntype;
  gchar **tokens = NULL;
  guint i;

  tokens = g_strsplit (scand, ",", 5);
  for (i = 0; tokens[i]; i++);
  if (i != 5)
    goto end;

  for (i = 0; i < G_N_ELEMENTS (candidate_type_name); i++) {
    if (strcmp(tokens[4], candidate_type_name[i]) == 0) {
      ntype = i;
      break;
    }
  }
  if (i == G_N_ELEMENTS (candidate_type_name))
    goto end;

  cand = nice_candidate_new(ntype);
  cand->component_id = 1;
  cand->stream_id = _stream_id;
  cand->transport = NICE_CANDIDATE_TRANSPORT_UDP;
  strncpy(cand->foundation, tokens[0], NICE_CANDIDATE_MAX_FOUNDATION);
  cand->foundation[NICE_CANDIDATE_MAX_FOUNDATION - 1] = 0;
  cand->priority = atoi (tokens[1]);

  if (!nice_address_set_from_string(&cand->addr, tokens[2])) {
    g_message("failed to parse addr: %s", tokens[2]);
    nice_candidate_free(cand);
    cand = NULL;
    goto end;
  }

  nice_address_set_port(&cand->addr, atoi (tokens[3]));

 end:
  g_strfreev(tokens);

  return cand;
}


char * 
str_local_data (NiceAgent *agent, guint _stream_id, guint component_id)
{
  fprintf(stderr,"LOCAL DATA\n");
  //int result = EXIT_FAILURE;
  gchar *local_ufrag = NULL;
  gchar *local_password = NULL;
  gchar ipaddr[INET6_ADDRSTRLEN];
  GSList *cands = NULL, *item;

  char * buffer = (char*)malloc(16*1024*sizeof(char));
  if (buffer==NULL) {
    PBPRINTF("failed to ammlloc buffer\n");
    exit(1);
  }
  buffer[0]='\0';

  if (!nice_agent_get_local_credentials(agent, _stream_id,
      &local_ufrag, &local_password))
    goto end;

  cands = nice_agent_get_local_candidates(agent, _stream_id, component_id);
  if (cands == NULL)
    goto end;


  int ret = sprintf(buffer, "%s %s", local_ufrag, local_password);

  for (item = cands; item; item = item->next) {
    NiceCandidate *c = (NiceCandidate *)item->data;

    nice_address_to_string(&c->addr, ipaddr);

    // (foundation),(prio),(addr),(port),(type)
    ret+= sprintf(buffer+ret," %s,%u,%s,%u,%s",
        c->foundation,
        c->priority,
        ipaddr,
        nice_address_get_port(&c->addr),
        candidate_type_name[c->type]);
  }
  //result = EXIT_SUCCESS;

 end:
  if (local_ufrag)
    g_free(local_ufrag);
  if (local_password)
    g_free(local_password);
  if (cands)
    g_slist_free_full(cands, (GDestroyNotify)&nice_candidate_free);

  return buffer;
}


static int
parse_remote_data(NiceAgent *agent, guint _stream_id,
    guint component_id, char *line)
{
  fprintf(stderr,"PARSE REMOTE DATA\n");
  GSList *remote_candidates = NULL;
  gchar **line_argv = NULL;
  const gchar *ufrag = NULL;
  const gchar *passwd = NULL;
  int result = EXIT_FAILURE;
  int i;

  line_argv = g_strsplit_set (line, " \t\n", 0);
  for (i = 0; line_argv && line_argv[i]; i++) {
    if (strlen (line_argv[i]) == 0)
      continue;

    // first two args are remote ufrag and password
    if (!ufrag) {
      ufrag = line_argv[i];
    } else if (!passwd) {
      passwd = line_argv[i];
    } else {
      // Remaining args are serialized canidates (at least one is required)
      NiceCandidate *c = parse_candidate(line_argv[i], _stream_id);

      if (c == NULL) {
        g_message("failed to parse candidate: %s", line_argv[i]);
        PBPRINTF("failed to parse candidate: %s", line_argv[i]);
        goto end;
      }
      remote_candidates = g_slist_prepend(remote_candidates, c);
    }
  }
  if (ufrag == NULL || passwd == NULL || remote_candidates == NULL) {
    g_message("line must have at least ufrag, password, and one candidate");
    PBPRINTF("line must have at least ufrag, password, and one candidate");
    goto end;
  }

  if (!nice_agent_set_remote_credentials(agent, _stream_id, ufrag, passwd)) {
    g_message("failed to set remote credentials");
    PBPRINTF("failed to set remote credentials");
    goto end;
  }

  // Note: this will trigger the start of negotiation.
  if (nice_agent_set_remote_candidates(agent, _stream_id, component_id,
      remote_candidates) < 1) {
    g_message("failed to set remote candidates");
    PBPRINTF("failed to set remote candidates");
    goto end;
  }

  result = EXIT_SUCCESS;

 end:
  if (line_argv != NULL)
    g_strfreev(line_argv);
  if (remote_candidates != NULL)
    g_slist_free_full(remote_candidates, (GDestroyNotify)&nice_candidate_free);

  return result;
}
