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

#include <semaphore.h>

#include <gst/gst.h>
#include <gst/video/video.h>
#include <agent.h>

sem_t negotiation_done;

static GMainLoop *gloop;
static GIOChannel* io_stdin, * gpipe;
guint stream_id;
NiceAgent *agent;

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
static gboolean stdin_remote_info_cb (GIOChannel *source, GIOCondition cond,
    gpointer data);
static gboolean stdin_send_data_cb (GIOChannel *source, GIOCondition cond,
    gpointer data);
NiceAgent * init_ice(int controlling, int to_parent, int from_parent);

//gchar * stun_addr = "stun.stunprotocol.org";
gchar * stun_addr = "159.203.252.147";
//gchar * stun_addr = "petbot.ca";
guint stun_port = 3478;

guint pipe_to_parent, pipe_from_parent;

void * start_ice_helper(void * x) {
	int * params = (int*)x;
	int controlling = params[0];
	int to_parent = params[1];
	int from_parent = params[2];
	init_ice(controlling, to_parent, from_parent);
    return NULL;
}

char * our_nice_string(int controlling) {
	sem_init(&negotiation_done, 0, 0);
	//make pipes	
	int to_child[2];
	int from_child[2];
	if (pipe(to_child)!=0 || pipe(from_child)!=0) {
		fprintf(stderr,"Failed to make pipes for children\n");
		exit(1);
	}
	//make ice thread
	pthread_t ice_thread;

	int params[3];
	params[0]=controlling;
	params[1]=from_child[1];
	params[2]=to_child[0];
	fprintf(stderr,"Starting ice helper x\n");
	int rc = pthread_create(&ice_thread, NULL, start_ice_helper, (void *)params);
	fprintf(stderr,"Starting ice helper 2\n");
	if (rc!=0) {
		fprintf(stderr,"failed to create ice thread\n");
		exit(1);
	}

	pbmsg * m = recv_fd_pbmsg(from_child[0]);
	char * our_nice = strdup(m->pbmsg);
	fprintf(stderr,"OUT NICE %s\n",our_nice);
	//Send message to the other side
	return our_nice;
}

void start_nice(pbsock * pbs) {
	sem_init(&negotiation_done, 0, 0);
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
		fprintf(stderr,"Failed to make pipes for children\n");
		exit(1);
	}

	//make ice thread
	pthread_t ice_thread;

	int params[3];
	params[0]=controlling;
	params[1]=from_child[1];
	params[2]=to_child[0];

	int rc = pthread_create(&ice_thread, NULL, start_ice_helper, (void *)params);
	if (rc!=0) {
		fprintf(stderr,"failed to create ice thread\n");
		exit(1);
	}

	m = recv_fd_pbmsg(from_child[0]);
	our_nice = strdup(m->pbmsg);
	//Send message to the other side
	send_pbmsg(pbs, m);
	pbmsg * mm = recv_pbmsg(pbs);
	other_nice = strdup(mm->pbmsg);
	free_pbmsg(mm);
        free_pbmsg(m);

	fprintf(stderr,"Our nice string, %s\n",our_nice);
	fprintf(stderr,"Other nice string %s\n",other_nice);
	
	m = new_pbmsg_from_str(other_nice);
	send_fd_pbmsg(to_child[1],m);
	free_pbmsg(m);

	//fprintf(stderr,"Waiting for negotiation to finish\n");
	sem_wait(&negotiation_done);
	//fprintf(stderr,"Waiting for negotiation to finish - Done - %p\n",agent);
}

NiceAgent * init_ice(int controlling, int to_parent, int from_parent) {
  fprintf(stderr,"Called init_ice\n");
  pipe_to_parent = to_parent;
  pipe_from_parent = from_parent;
  if (controlling != 0 && controlling != 1) {
    fprintf(stderr, "controlling must be 1 or 0\n");
    exit(1);
  }

  fprintf(stderr,"Using stun server '[%s]:%u'\n", stun_addr, stun_port);

  g_type_init();

  gloop = g_main_loop_new(NULL, FALSE);
  gpipe = g_io_channel_unix_new(from_parent);
  io_stdin = g_io_channel_unix_new(fileno(stdin));

  // Create the nice agent
  agent = nice_agent_new(g_main_loop_get_context (gloop),
      NICE_COMPATIBILITY_RFC5245);
  if (agent == NULL)
    g_error("Failed to create agent");
  

  // Set the STUN settings and controlling mode
  if (stun_addr) {
    g_object_set(agent, "stun-server", stun_addr, NULL);
    g_object_set(agent, "stun-server-port", stun_port, NULL);
  }
  g_object_set(agent, "controlling-mode", controlling, NULL);

  // Connect to the signals
  g_signal_connect(agent, "candidate-gathering-done",
      G_CALLBACK(cb_candidate_gathering_done), NULL);
  g_signal_connect(agent, "new-selected-pair",
      G_CALLBACK(cb_new_selected_pair), NULL);
  g_signal_connect(agent, "component-state-changed",
      G_CALLBACK(cb_component_state_changed), NULL);

  // Create a new stream with one component
  stream_id = nice_agent_add_stream(agent, 1);
  if (stream_id == 0)
    g_error("Failed to add stream");
    gboolean ret = nice_agent_set_relay_info(agent,stream_id,1,stun_addr, stun_port, "misko", "misko",NICE_RELAY_TYPE_TURN_UDP);


  // Attach to the component to receive the data
  // Without this call, candidates cannot be gathered
  nice_agent_attach_recv(agent, stream_id, 1,
      g_main_loop_get_context (gloop), cb_nice_recv, NULL);

  // Start gathering local candidates
  if (!nice_agent_gather_candidates(agent, stream_id))
    g_error("Failed to start candidate gathering");

  g_debug("waiting for candidate-gathering-done signal...");

  // Run the mainloop. Everything else will happen asynchronously
  // when the candidates are done gathering.
  g_main_loop_run (gloop);

  g_main_loop_unref(gloop);
  g_object_unref(agent);
  g_io_channel_unref (io_stdin);

  return agent;
}


static void
cb_candidate_gathering_done(NiceAgent *agent, guint _stream_id,
    gpointer data)
{

  g_debug("SIGNAL candidate gathering done\n");

  // Candidate gathering is done. Send our local candidates on stdout
  //printf("Copy this line to remote client:\n");
  //printf("\n  ");
  char * s = str_local_data(agent, _stream_id, 1);
  pbmsg * m = new_pbmsg_from_str(s);
  send_fd_pbmsg(pipe_to_parent, m);
  free_pbmsg(m); 

  //fprintf(stderr, "Waiting to recv message from other side..\n");
  // Listen on stdin for the remote candidate list
  //printf("Enter remote data (single line, no wrapping):\n");
  g_io_add_watch(gpipe, G_IO_IN, stdin_remote_info_cb, agent);
  printf("> ");
  fflush (stdout);
}

static gboolean
stdin_remote_info_cb (GIOChannel *source, GIOCondition cond,
    gpointer data)
{
  NiceAgent *agent = data;
  gchar *line = NULL;
  int rval;
  gboolean ret = TRUE;

  pbmsg * m = recv_fd_pbmsg(pipe_from_parent);
  fprintf(stderr, "Remote info is %s\n",m->pbmsg);
  rval = parse_remote_data(agent, stream_id, 1, m->pbmsg);
  ret = FALSE; //return false for CB so its stops listenting
  return ret;
}

static void
cb_component_state_changed(NiceAgent *agent, guint _stream_id,
    guint component_id, guint state,
    gpointer data)
{

  g_debug("SIGNAL: state changed %d %d %s[%d]\n",
      _stream_id, component_id, state_name[state], state);

  if (state == NICE_COMPONENT_STATE_READY) {
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

    // Listen to stdin and send data written to it
    printf("\nSend lines to remote (Ctrl-D to quit):\n");
    g_io_add_watch(io_stdin, G_IO_IN, stdin_send_data_cb, agent);
    printf("> ");
    fflush (stdout);
    sem_post(&negotiation_done);
  } else if (state == NICE_COMPONENT_STATE_FAILED) {
    sem_post(&negotiation_done);
    g_main_loop_quit (gloop);
    agent=NULL;
  }
}

static gboolean
stdin_send_data_cb (GIOChannel *source, GIOCondition cond,
    gpointer data)
{
  NiceAgent *agent = data;
  gchar *line = NULL;

  if (g_io_channel_read_line (source, &line, NULL, NULL, NULL) ==
      G_IO_STATUS_NORMAL) {
    nice_agent_send(agent, stream_id, 1, strlen(line), line);
    g_free (line);
    printf("> ");
    fflush (stdout);
  } else {
    nice_agent_send(agent, stream_id, 1, 1, "\0");
    // Ctrl-D was pressed.
    g_main_loop_quit (gloop);
  }

  return TRUE;
}

static void
cb_new_selected_pair(NiceAgent *agent, guint _stream_id,
    guint component_id, gchar *lfoundation,
    gchar *rfoundation, gpointer data)
{
  g_debug("SIGNAL: selected pair %s %s", lfoundation, rfoundation);
}

static void
cb_nice_recv(NiceAgent *agent, guint _stream_id, guint component_id,
    guint len, gchar *buf, gpointer data)
{
  if (len == 1 && buf[0] == '\0')
    g_main_loop_quit (gloop);
  printf("%.*s", len, buf);
  fflush(stdout);
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
  int result = EXIT_FAILURE;
  gchar *local_ufrag = NULL;
  gchar *local_password = NULL;
  gchar ipaddr[INET6_ADDRSTRLEN];
  GSList *cands = NULL, *item;

  if (!nice_agent_get_local_credentials(agent, _stream_id,
      &local_ufrag, &local_password))
    goto end;

  cands = nice_agent_get_local_candidates(agent, _stream_id, component_id);
  if (cands == NULL)
    goto end;

  char * buffer = (char*)malloc(2048*sizeof(char));
  if (buffer==NULL) {
    fprintf(stderr,"failed to ammlloc buffer\n");
    exit(1);
  }

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
  result = EXIT_SUCCESS;

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
        goto end;
      }
      remote_candidates = g_slist_prepend(remote_candidates, c);
    }
  }
  if (ufrag == NULL || passwd == NULL || remote_candidates == NULL) {
    g_message("line must have at least ufrag, password, and one candidate");
    goto end;
  }

  if (!nice_agent_set_remote_credentials(agent, _stream_id, ufrag, passwd)) {
    g_message("failed to set remote credentials");
    goto end;
  }

  // Note: this will trigger the start of negotiation.
  if (nice_agent_set_remote_candidates(agent, _stream_id, component_id,
      remote_candidates) < 1) {
    g_message("failed to set remote candidates");
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
