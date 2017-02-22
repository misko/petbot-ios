#import "GStreamerBackend.h"
#import "VideoViewController.h"
#include <gst/gst.h>
#include <gst/video/video.h>
#include <agent.h>

#include "tcp_utils.h"
#include "nice_utils.h"
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>


GST_DEBUG_CATEGORY_STATIC (debug_category);
#define GST_CAT_DEFAULT debug_category

@interface GStreamerBackend()
-(void)setUIMessage:(gchar*) message;
-(void)app_functionPBNIO;
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
    int launched;
    VideoViewController * vvc;
    guint64 * jitter_stats;
    GstElement *nicesrc, *rtph264depay, *avdec_h264, *videoconvert, *autovideosink,*rtpjitterbuffer;
}

/*
 * Interface methods
 */

-(id) init:(id) uiDelegate videoView:(UIView *)video_view vvc:(VideoViewController *)vvcx
{
    nicesrc=NULL;
    rtph264depay=NULL;
    avdec_h264=NULL;
    videoconvert=NULL;
    autovideosink=NULL;
    rtpjitterbuffer=NULL;
    jitter_stats=(guint64*)malloc(sizeof(guint64)*3);
    if (jitter_stats==NULL) {
        PBPRINTF("ERROR MALLOC!");
        exit(1);
    }
    main_loop=nil;
    launched=0;
    self->vvc = vvcx;
    if (self = [super init]) {
        
        self->ui_delegate = uiDelegate;
        self->ui_video_view = video_view;
        
        GST_DEBUG_CATEGORY_INIT (debug_category, "gst-petbot ios", 0, "gst-petbot ios");
        gst_debug_set_threshold_for_name("gst-petbot ios", GST_LEVEL_DEBUG);
        
        /* Start the bus monitoring task */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self init_glib];
        });
    }

    return self;
}

-(void) init_glib {
    /* Create our own GLib Main Context and make it the default one */
    //context = g_main_context_new ();
    //g_main_context_push_thread_default(context);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        GST_DEBUG ("Entering main loop...");
        fprintf(stderr,"ENTER MAIN LOOP\n");
        main_loop = g_main_loop_new (NULL, FALSE);
        g_main_loop_run (main_loop);
        //g_main_context_unref (context);
        
        

        [self->vvc toLogin];
    });
    fprintf(stderr,"Glib loop started\n");
}

-(void) quit {
    @synchronized(self) {
    /*PBPRINTF("CALLING QUIT\n");
    if (pipeline!=NULL) {
        PBPRINTF("CALLING QUIT x1\n");
        gst_element_set_state (pipeline, GST_STATE_NULL);
        pipeline=NULL;
    }
    if (main_loop!=nil) {
        PBPRINTF("CALLING QUIT x2\n");
        nicesrc=NULL;
        rtph264depay=NULL;
        avdec_h264=NULL;
        videoconvert=NULL;
        autovideosink=NULL;
        rtpjitterbuffer=NULL;
        g_main_loop_quit(main_loop);
        g_main_loop_unref (main_loop);
        main_loop=NULL;
    }
    PBPRINTF("CALLING QUITx 4\n");*/
    if (main_loop!=NULL) {
        g_main_loop_quit(main_loop);
        g_main_loop_unref (main_loop);
        main_loop = NULL;
        
        if (launched==1) {
            gst_element_set_state (pipeline, GST_STATE_NULL);
            gst_object_unref (pipeline);
            pipeline=NULL;
        }
        fprintf(stderr,"EXIT MAIN LOOP xxx\n");
    }
    }
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

-(guint64*)get_jitter_stats {
    
    @synchronized(self) {
    if (main_loop!=NULL && rtpjitterbuffer!=NULL) {
        GstStructure * stats;
        g_object_get (rtpjitterbuffer, "stats", &stats, NULL);
        //guint64 rtx_count, rtx_success_count, rtx_rtt, percent;
        //guint64 num_pushed,num_lost,num_late;
        //gdouble rtx_per_packet;
        /*gst_structure_get_uint64 (stats, "rtx-count", &rtx_count);
        gst_structure_get_uint64 (stats, "rtx-success-count", &rtx_success_count);
        gst_structure_get_double (stats, "rtx-per-packet", &rtx_per_packet);
        gst_structure_get_uint64 (stats, "rtx-rtt", &rtx_rtt);*/
        gst_structure_get_uint64 (stats, "num-pushed", jitter_stats);
        gst_structure_get_uint64 (stats, "num-lost", jitter_stats+1);
        gst_structure_get_uint64 (stats, "num-late", jitter_stats+2);
        
        //NSLog(@"PUSHED %ld %ld %ld\n",num_pushed,num_lost,num_late);
        //NSLog(@"PUSHED %ld %ld %e\n",rtx_count,rtx_success_count,rtx_per_packet);
        return jitter_stats;
    }
    return nil;
    }
}

-(uint) get_frames_rendered {
    guint frames_redendered = 0;
    if (autovideosink!=NULL) {
        g_object_get(autovideosink,"frames-rendered",&frames_redendered,NULL);
        [self get_jitter_stats];
    }
    return frames_redendered;
}

/* Main method for the bus monitoring code */
-(void) app_functionPBNIO:(pb_nice_io *)pbnio
{
    GstBus *bus;
    GSource *bus_source;

    GST_DEBUG ("Creating pipeline");

    
    /* Build pipeline */
    nicesrc = gst_element_factory_make ("nicesrc", "nicesrc");
    fprintf(stderr,"nicesrc %p\n",nicesrc);
    rtph264depay = gst_element_factory_make ("rtph264depay", "rtph264depay");
    fprintf(stderr,"rtph264depay %p\n",rtph264depay);
    avdec_h264 = gst_element_factory_make ("avdec_h264", "avdec_h264");
    fprintf(stderr,"avdec_h264 %p\n",avdec_h264);
    videoconvert = gst_element_factory_make ("videoconvert", "videoconvert");
    fprintf(stderr,"videoconvert %p\n",videoconvert);
    rtpjitterbuffer = gst_element_factory_make("rtpjitterbuffer", "rtpjitterbuffer");
    fprintf(stderr,"rtpjitterbuffer %p\n",rtpjitterbuffer);
    autovideosink = gst_element_factory_make ("fpsdisplaysink", "fpsdisplaysink");
    
    g_object_set (autovideosink, "text-overlay", FALSE, NULL);
    fprintf(stderr,"autovideosink %p\n",autovideosink);
    
    g_object_set (nicesrc, "agent", pbnio->agent, NULL);
    g_object_set (nicesrc, "stream", pbnio->stream_id, NULL);
    g_object_set (nicesrc, "component", 1, NULL);
    
    GstCaps *nicesrc_caps = gst_caps_from_string("application/x-rtp, media=(string)video, clock-rate=(int)90000, encoding-name=(string)H264, payload=96");
    
    g_object_set( G_OBJECT(autovideosink), "sync", FALSE, NULL);
    /* Create the empty pipeline */
    pipeline = gst_pipeline_new ("send-pipeline");
    
    /* Build the pipeline */
    gst_bin_add_many (GST_BIN (pipeline), nicesrc, rtpjitterbuffer, rtph264depay, avdec_h264, videoconvert, autovideosink,  NULL);
    if (!gst_element_link_filtered( nicesrc, rtpjitterbuffer, nicesrc_caps)) {
        fprintf(stderr,"Failed to link 1\n");
        [self quit];
        return;
        //exit(1);
    }
    if (!gst_element_link_many(rtpjitterbuffer, rtph264depay,avdec_h264,videoconvert,autovideosink,NULL)) {
        fprintf(stderr,"Failed to link 2\n");
        
        [self quit];
        return;
        //exit(1);
    }
    
    //g_object_set( G_OBJECT(nicesrc), "port", udp_port,NULL);
    g_object_set( G_OBJECT(autovideosink), "sync",FALSE,NULL);
    
    //gst_element_set_state(pipeline, GST_STATE_READY);
    if(gst_element_set_state(pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
        [self setUIMessage:"Failed to set pipeline to playing"];
    }
    
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
    
    [ui_delegate gstreamerHideLoadView];
    
    /* Create a GLib Main Loop and set it to run */
    //GST_DEBUG ("Entering main loop...");
    //main_loop = g_main_loop_new (context, FALSE);
    [self check_initialization_complete];
    launched=1;
    return;
   /* g_main_loop_run (main_loop); //TODO WE ALREADY CALL RUN MAIN somewhere else.. do we need this?
    //GST_DEBUG ("Exited main loop");
    g_main_loop_unref (main_loop);
    main_loop = NULL;
    fprintf(stderr,"Exitted main loop!");
    //g_main_context_pop_thread_default(context);
    fprintf(stderr,"X11\n");
    g_main_context_unref (context);
    fprintf(stderr,"X111\n");
    gst_element_set_state (pipeline, GST_STATE_NULL);
    fprintf(stderr,"X11111\n");
    gst_object_unref (pipeline);
    fprintf(stderr,"X1\n");
    [self->vc toLogin];
    return;*/
}

@end

