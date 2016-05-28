#import "GStreamerBackend.h"

#include <gst/gst.h>
#include <gst/video/video.h>
#include <agent.h>

#include "tcp_utils.h"
#include "nice.h"
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>


GST_DEBUG_CATEGORY_STATIC (debug_category);
#define GST_CAT_DEFAULT debug_category

@interface GStreamerBackend()
-(void)setUIMessage:(gchar*) message;
-(void)app_function;
-(void)check_initialization_complete;
@end

@implementation GStreamerBackend {
    id ui_delegate;        /* Class that we use to interact with the user interface */
    GstElement *pipeline;  /* The running pipeline */
    GstElement *video_sink;/* The video sink element which receives XOverlay commands */
    GMainContext *context; /* GLib context used to run the main loop */
    GMainLoop *main_loop;  /* GLib main loop */
    gboolean initialized;  /* To avoid informing the UI multiple times about the initialization */
    UIView *ui_video_view; /* UIView that holds the video */
    NSDictionary * loginInfo;
    const char * pubsubserver_secret;
    const char * pubsubserver_server;
    const char * pubsubserver_username;
    const char * pubsubserver_protocol;
    int pubsubserver_port;
    pbsock * pbs;
    NSString * petbot_state; //connecting, ice_request, ice_negotiate, streaming, logoff
}

-(void) listenForEvents {
    pbmsg * m = recv_pbmsg(pbs);
    if ((m->pbmsg_type ^  (PBMSG_EVENT | PBMSG_RESPONSE_SUCCESS | PBMSG_ICE_EVENT))==0) {
        fprintf(stderr,"GOT A ICE RESPONSE BACK!\n");
        [self ice_negotiate:m];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
}

-(void) connect {
    fprintf(stderr, "pbstate: Connecting...");
#ifdef PBSSL
    SSL_CTX* ctx;
    OpenSSL_add_ssl_algorithms();
    SSL_load_error_strings();
    ctx = SSL_CTX_new (SSLv23_client_method());
    pbs = connect_to_server_with_key(pubsubserver_server,pubsubserver_port,ctx,pubsubserver_secret);
#else
    pbs = connect_to_server_with_key(pbhost,port,key);
#endif
    if (pbs==NULL) {
        //TODO error handling!!!!
        exit(1);
    }
    
    //start up the listener
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self listenForEvents];
    });
    
    start_nice_thread();
    
    petbot_state = @"pbstate: ice_request";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self ice_request];
    });
}

-(void) ice_request {
    pbmsg * ice_request_m = make_ice_request();
    fprintf(stderr,"make the ice request!\n");
    send_pbmsg(pbs, ice_request_m);
    fprintf(stderr,"made the ice request\n");
}

-(void) ice_negotiate:(pbmsg *)m {
    recvd_ice_response(m);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self app_function];
    });
    fprintf(stderr,"LAUNCHED APP FUNCTION\n");
}


/*
 * Interface methods
 */

-(id) init:(id) uiDelegate videoView:(UIView *)video_view serverInfo:(NSDictionary *)loginInfo
{
    petbot_state = @"connecting";
    //TODO check for errors here?
    self->loginInfo=loginInfo;
    pubsubserver_port = [[self->loginInfo objectForKey:@"port"] intValue];
    pubsubserver_secret = [[self->loginInfo objectForKey:@"secret"] UTF8String];
    pubsubserver_server = [[self->loginInfo objectForKey:@"server"] UTF8String];
    pubsubserver_username = [[self->loginInfo objectForKey:@"username"] UTF8String];
    if (self = [super init])
    {
        
        self->ui_delegate = uiDelegate;
        self->ui_video_view = video_view;
        
        GST_DEBUG_CATEGORY_INIT (debug_category, "tutorial-3", 0, "iOS tutorial 3");
        gst_debug_set_threshold_for_name("tutorial-3", GST_LEVEL_DEBUG);
        
        
        /* Start the bus monitoring task */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self init_glib];
        });
        
        /* Start the bus monitoring task */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self connect];
        });
        
        

    }

    return self;
}

-(void) init_glib {
    /* Create our own GLib Main Context and make it the default one */
    context = g_main_context_new ();
    g_main_context_push_thread_default(context);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        GST_DEBUG ("Entering main loop...");
        main_loop = g_main_loop_new (NULL, FALSE);
        g_main_loop_run (main_loop);
        GST_DEBUG ("Exited main loop");
    });
    fprintf(stderr,"Glib loop started\n");
}


-(void) dealloc
{
    if (pipeline) {
        GST_DEBUG("Setting the pipeline to NULL");
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        pipeline = NULL;
    }
}

-(void) play
{
    if(gst_element_set_state(pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        [self setUIMessage:"Failed to set pipeline to playing"];
    }
}

-(void) pause
{
    if(gst_element_set_state(pipeline, GST_STATE_PAUSED) == GST_STATE_CHANGE_FAILURE) {
        [self setUIMessage:"Failed to set pipeline to paused"];
    }
}

/*
 * Private methods
 */

/* Change the message on the UI through the UI delegate */
-(void)setUIMessage:(gchar*) message
{
    NSString *string = [NSString stringWithUTF8String:message];
    if(ui_delegate && [ui_delegate respondsToSelector:@selector(gstreamerSetUIMessage:)])
    {
        [ui_delegate gstreamerSetUIMessage:string];
    }
}

/* Retrieve errors from the bus and show them on the UI */
static void error_cb (GstBus *bus, GstMessage *msg, GStreamerBackend *self)
{
    GError *err;
    gchar *debug_info;
    gchar *message_string;
    
    gst_message_parse_error (msg, &err, &debug_info);
    message_string = g_strdup_printf ("Error received from element %s: %s", GST_OBJECT_NAME (msg->src), err->message);
    g_clear_error (&err);
    g_free (debug_info);
    [self setUIMessage:message_string];
    g_free (message_string);
    gst_element_set_state (self->pipeline, GST_STATE_NULL);
}

/* Notify UI about pipeline state changes */
static void state_changed_cb (GstBus *bus, GstMessage *msg, GStreamerBackend *self)
{
    GstState old_state, new_state, pending_state;
    gst_message_parse_state_changed (msg, &old_state, &new_state, &pending_state);
    /* Only pay attention to messages coming from the pipeline, not its children */
    if (GST_MESSAGE_SRC (msg) == GST_OBJECT (self->pipeline)) {
        gchar *message = g_strdup_printf("State changed to %s", gst_element_state_get_name(new_state));
        [self setUIMessage:message];
        g_free (message);
    }
}

/* Check if all conditions are met to report GStreamer as initialized.
 * These conditions will change depending on the application */
-(void) check_initialization_complete
{
    if (!initialized && main_loop) {
        GST_DEBUG ("Initialization complete, notifying application.");
        if (ui_delegate && [ui_delegate respondsToSelector:@selector(gstreamerInitialized)])
        {
            [ui_delegate gstreamerInitialized];
        }
        initialized = TRUE;
    }
}

/* Main method for the bus monitoring code */
-(void) app_function
{


    GstBus *bus;
    GSource *bus_source;

    GST_DEBUG ("Creating pipeline");

    
    
    /* Build pipeline */
    GstElement *nicesrc, *rtph264depay, *avdec_h264, *videoconvert, *autovideosink;
    nicesrc = gst_element_factory_make ("nicesrc", "nicesrc");
    fprintf(stderr,"nicesrc %p\n",nicesrc);
    rtph264depay = gst_element_factory_make ("rtph264depay", "rtph264depay");
    fprintf(stderr,"rtph264depay %p\n",rtph264depay);
    avdec_h264 = gst_element_factory_make ("avdec_h264", "avdec_h264");
    fprintf(stderr,"avdec_h264 %p\n",avdec_h264);
    videoconvert = gst_element_factory_make ("videoconvert", "videoconvert");
    fprintf(stderr,"videoconvert %p\n",videoconvert);
    autovideosink = gst_element_factory_make ("autovideosink", "autovideosink");
    fprintf(stderr,"autovideosink %p\n",autovideosink);
    
    g_object_set (nicesrc, "agent", agent, NULL);
    g_object_set (nicesrc, "stream", stream_id, NULL);
    g_object_set (nicesrc, "component", 1, NULL);
    
    GstCaps *nicesrc_caps = gst_caps_from_string("application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264, payload=96");
    
    /* Create the empty pipeline */
    pipeline = gst_pipeline_new ("send-pipeline");
    
    /* Build the pipeline */
    gst_bin_add_many (GST_BIN (pipeline), nicesrc, rtph264depay, avdec_h264, videoconvert, autovideosink,  NULL);
    if (!gst_element_link_filtered( nicesrc, rtph264depay, nicesrc_caps)) {
        fprintf(stderr,"Failed to link 1\n");
        exit(1);
    }
    if (!gst_element_link_many(rtph264depay,avdec_h264,videoconvert,autovideosink,NULL)) {
        fprintf(stderr,"Failed to link 2\n");
        exit(1);
    }
    
    //g_object_set( G_OBJECT(nicesrc), "port", udp_port,NULL);
    g_object_set( G_OBJECT(autovideosink), "sync",FALSE,NULL);
    
    
    /*pipeline = gst_parse_launch("videotestsrc ! warptv ! videoconvert ! autovideosink", &error);
    if (error) {
        gchar *message = g_strdup_printf("Unable to build pipeline: %s", error->message);
        g_clear_error (&error);
        [self setUIMessage:message];
        g_free (message);
        return;
    }*/

    /* Set the pipeline to READY, so it can already accept a window handle */
    gst_element_set_state(pipeline, GST_STATE_READY);
    
    video_sink = gst_bin_get_by_interface(GST_BIN(pipeline), GST_TYPE_VIDEO_OVERLAY);
    if (!video_sink) {
        GST_ERROR ("Could not retrieve video sink");
        return;
    }
    gst_video_overlay_set_window_handle(GST_VIDEO_OVERLAY(video_sink), (guintptr) (id) ui_video_view);

    /* Instruct the bus to emit signals for each received message, and connect to the interesting signals */
    bus = gst_element_get_bus (pipeline);
    bus_source = gst_bus_create_watch (bus);
    g_source_set_callback (bus_source, (GSourceFunc) gst_bus_async_signal_func, NULL, NULL);
    g_source_attach (bus_source, NULL);
    g_source_unref (bus_source);
    g_signal_connect (G_OBJECT (bus), "message::error", (GCallback)error_cb, (__bridge void *)self);
    g_signal_connect (G_OBJECT (bus), "message::state-changed", (GCallback)state_changed_cb, (__bridge void *)self);
    gst_object_unref (bus);
    
    /* Create a GLib Main Loop and set it to run */
    //GST_DEBUG ("Entering main loop...");
    //main_loop = g_main_loop_new (context, FALSE);
    [self check_initialization_complete];
    g_main_loop_run (main_loop);
    //GST_DEBUG ("Exited main loop");
    //g_main_loop_unref (main_loop);
    //main_loop = NULL;
    
    /* Free resources */
    //g_main_context_pop_thread_default(context);
    //g_main_context_unref (context);
    //gst_element_set_state (pipeline, GST_STATE_NULL);
    //gst_object_unref (pipeline);
    
    return;
}

@end

