#include <re.h>         // MUST precede baresip.h to define size_t and memory allocators
#include <rem.h>
#include <baresip.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

static int fifo_fd = -1;
static struct auplay *aup = NULL;
const char *pipe_path = "/tmp/majestic_speaker.pcm";

// Baresip requires the state struct to be allocated, otherwise it segfaults.
struct auplay_st {
    int dummy;
};

static void aupipe_destructor(void *arg) {
    (void)arg; // Suppress unused warning
}

/* * The synchronous hook triggered by 0002-send-rtp-data.patch.
 * Bypasses Baresip's auplay ring-buffers entirely.
 */
static void aupipe_send_handler(const void *sampv, size_t sampc) {
    if (fifo_fd >= 0) {
        // write() directly to the RAMdisk pipe
        if (write(fifo_fd, sampv, sampc * 2) < 0) {
            // Ignore EAGAIN if the pipe fills to prevent blocking
        }
    }
}

static int aupipe_alloc(struct auplay_st **stp, const struct auplay *ap,
                        struct auplay_prm *prm, const char *device,
                        auplay_write_h *wh, void *arg) {
    struct auplay_st *st;
    
    // Cast unused variables to suppress GCC warnings
    (void)ap;
    (void)prm;
    (void)device;
    (void)wh;
    (void)arg;
    
    // Allocate the Baresip player state
    st = mem_zalloc(sizeof(*st), aupipe_destructor);
    if (!st) return ENOMEM;
    
    // Establish the IPC pipe
    mkfifo(pipe_path, 0666);
    fifo_fd = open(pipe_path, O_RDWR | O_NONBLOCK); 
    if (fifo_fd < 0) {
        warning("aupipe: failed to open %s (errno=%d)\n", pipe_path, errno);
        mem_deref(st);
        return errno;
    }
    
    info("aupipe: Zero-latency pipe established to %s\n", pipe_path);
    *stp = st;
    return 0;
}

static int module_init(void) {
    int err = auplay_register(&aup, baresip_auplayl(), "aupipe", aupipe_alloc);
    if (!err && aup) {
        // Bind the patch pointer (types now perfectly match thanks to re.h)
        aup->asendh = aupipe_send_handler; 
    }
    return err;
}

static int module_close(void) {
    if (fifo_fd >= 0) close(fifo_fd);
    
    // Baresip 3.x uses mem_deref instead of auplay_unregister
    aup = mem_deref(aup);
    return 0;
}

// Baresip 3.x Strict Module Export Macro
EXPORT_SYM const struct mod_export DECL_EXPORTS(aupipe) = {
    "aupipe",
    "audio",
    module_init,
    module_close
};
