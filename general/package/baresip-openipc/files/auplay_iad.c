#include <re.h>
#include <rem.h>
#include <baresip.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <pthread.h>

struct auplay_st {
    int sockfd;
    pthread_t thread;
    volatile bool run;
    auplay_write_h *wh;
    void *arg;
};

static void *auplay_thread(void *arg) {
    struct auplay_st *st = arg;
    // 20ms of 16kHz audio = 320 samples
    int16_t sampv[320]; 
    size_t sampc = 320;

    while (st->run) {
        // Pull 20ms from Baresip internal buffer
        st->wh(sampv, sampc, st->arg);

        // Blocking send to Sigmastar Audio Daemon
        // The daemon's 200ms DMA timeout and socket buffer acts as our master clock
        ssize_t n = send(st->sockfd, sampv, sampc * sizeof(int16_t), MSG_NOSIGNAL);
        if (n < 0) {
            warning("auplay_iad: socket write failed (daemon closed?)\n");
            break;
        }
    }
    return NULL;
}

static void auplay_destruct(void *arg) {
    struct auplay_st *st = arg;
    st->run = false;
    if (st->sockfd >= 0) {
        close(st->sockfd); // Force EOF to break daemon read loop
    }
    pthread_join(st->thread, NULL);
}

static int auplay_alloc(struct auplay_st **stp, const struct auplay *ap,
                        struct auplay_prm *prm, const char *device,
                        auplay_write_h *wh, void *arg) {
    struct auplay_st *st;
    struct sockaddr_un addr;
    int err = 0;

    if (!stp || !ap || !prm || !wh) return EINVAL;

    // Force Baresip resampler to match the SigmaStar VQE DSP constraints
    prm->srate = 16000;
    prm->ch    = 1;
    prm->fmt   = AUFMT_S16LE;

    st = mem_zalloc(sizeof(*st), auplay_destruct);
    if (!st) return ENOMEM;

    st->wh  = wh;
    st->arg = arg;
    st->run = true;

    // Connect to the SigmaStar AO Socket
    st->sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, "/tmp/audio_output.sock", sizeof(addr.sun_path) - 1);

    if (connect(st->sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        warning("auplay_iad: Failed to connect to %s\n", addr.sun_path);
        mem_deref(st);
        return errno;
    }

    err = pthread_create(&st->thread, NULL, auplay_thread, st);
    if (err) {
        mem_deref(st);
        return err;
    }

    *stp = st;
    return 0;
}

static struct auplay *auplay = NULL;

static int module_init(void) {
    return auplay_register(&auplay, baresip_auplayl(), "iad", auplay_alloc);
}

static int module_close(void) {
    auplay = mem_deref(auplay);
    return 0;
}

EXPORT_SYM const struct mod_export DECL_EXPORTS(auplay_iad) = {
    "iad",
    "auplay",
    module_init,
    module_close
};
