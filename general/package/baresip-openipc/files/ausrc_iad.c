#include <re.h>
#include <rem.h>
#include <baresip.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <pthread.h>
#include <string.h> // Added for memset and strncpy
#include <errno.h>

struct ausrc_st {
    int sockfd;
    pthread_t thread;
    volatile bool run;
    ausrc_read_h *rh;
    void *arg;
};

static void *ausrc_thread(void *arg) {
    struct ausrc_st *st = arg;
    int16_t sampv[320]; 

    while (st->run) {
        ssize_t n = recv(st->sockfd, sampv, sizeof(sampv), MSG_WAITALL);
        
        if (n == sizeof(sampv)) {
            // Encapsulate raw PCM buffer into the expected Baresip auframe struct
            struct auframe af;
            auframe_init(&af, AUFMT_S16LE, sampv, n / sizeof(int16_t), 16000, 1);
            
            // Push structured auframe to Baresip's SIP encoder
            st->rh(&af, st->arg);
        } else if (n <= 0) {
            warning("ausrc_iad: socket read failed/EOF\n");
            break;
        }
    }
    return NULL;
}

static void ausrc_destruct(void *arg) {
    struct ausrc_st *st = arg;
    st->run = false;
    if (st->sockfd >= 0) close(st->sockfd);
    pthread_join(st->thread, NULL);
}

// Renamed to avoid colliding with Baresip's global ausrc_alloc declaration
static int iad_ausrc_alloc(struct ausrc_st **stp, const struct ausrc *as,
                           struct ausrc_prm *prm, const char *device,
                           ausrc_read_h *rh, ausrc_error_h *errh, void *arg) {
    struct ausrc_st *st;
    struct sockaddr_un addr;
    int err = 0;

    if (!stp || !as || !prm || !rh) return EINVAL;

    prm->srate = 16000;
    prm->ch    = 1;
    prm->fmt   = AUFMT_S16LE;

    st = mem_zalloc(sizeof(*st), ausrc_destruct);
    if (!st) return ENOMEM;

    st->rh  = rh;
    st->arg = arg;
    st->run = true;

    st->sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, "/tmp/audio_input.sock", sizeof(addr.sun_path) - 1);

    if (connect(st->sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        warning("ausrc_iad: Failed to connect to %s\n", addr.sun_path);
        mem_deref(st);
        return errno;
    }

    err = pthread_create(&st->thread, NULL, ausrc_thread, st);
    if (err) {
        mem_deref(st);
        return err;
    }

    *stp = st;
    return 0;
}

static struct ausrc *ausrc = NULL;

static int module_init(void) {
    return ausrc_register(&ausrc, baresip_ausrcl(), "iad", iad_ausrc_alloc);
}

static int module_close(void) {
    ausrc = mem_deref(ausrc);
    return 0;
}

EXPORT_SYM const struct mod_export DECL_EXPORTS(ausrc_iad) = {
    "iad",
    "ausrc",
    module_init,
    module_close
};
