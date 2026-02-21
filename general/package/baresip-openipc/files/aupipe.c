#include <baresip.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

static int fifo_fd = -1;
static struct auplay *aup = NULL;
const char *pipe_path = "/tmp/majestic_speaker.pcm";

/* * The synchronous hook triggered by 0002-send-rtp-data.patch 
 * Bypasses Baresip's auplay ring-buffers entirely.
 */
static void aupipe_send_handler(const void *sampv, size_t sampc) {
    if (fifo_fd >= 0) {
        // Non-blocking write to tmpfs. sampc * 2 because G.711/Opus decodes to 16-bit PCM.
        // If the pipe fills up (Majestic lags), we drop the frame rather than 
        // blocking the Baresip RX thread and accumulating massive latency.
        write(fifo_fd, sampv, sampc * 2); 
    }
}

static int aupipe_alloc(struct auplay_st **stp, const struct auplay *ap,
                        struct auplay_prm *prm, const char *device,
                        auplay_write_h *wh, void *arg) {
    
    // Ensure the RAMdisk pipe exists
    mkfifo(pipe_path, 0666);
    
    // Open in non-blocking mode to prevent SIP thread lockups
    fifo_fd = open(pipe_path, O_RDWR | O_NONBLOCK); 
    if (fifo_fd < 0) {
        warning("aupipe: failed to open %s (errno=%d)\n", pipe_path, errno);
        return errno;
    }
    
    info("aupipe: Zero-latency pipe established to %s\n", pipe_path);
    return 0;
}

int module_init(void) {
    int err = auplay_register(&aup, baresip_auplayl(), "aupipe", aupipe_alloc);
    if (!err && aup) {
        aup->asendh = aupipe_send_handler; // Bind the patch pointer
    }
    return err;
}

int module_close(void) {
    if (fifo_fd >= 0) close(fifo_fd);
    auplay_unregister(aup);
    return 0;
}
