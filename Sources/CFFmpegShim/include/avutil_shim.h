#ifndef CFFMPEGSHIM_AVUTIL_SHIM_H
#define CFFMPEGSHIM_AVUTIL_SHIM_H

#include <libavutil/avutil.h>
#include <libavutil/error.h>
#include <libavutil/log.h>
#include <libavutil/rational.h>
#include <libavutil/mathematics.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libavutil/pixfmt.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/dict.h>
#include <libavutil/frame.h>
#include <libavutil/mem.h>

#include <stdint.h>

// ---------- AVERROR macro shims ----------

static inline int cffmpeg_AVERROR(int e) {
    return AVERROR(e);
}

static inline int cffmpeg_AVERROR_EOF(void) {
    return AVERROR_EOF;
}

static inline int cffmpeg_AVERROR_EAGAIN(void) {
    return AVERROR(EAGAIN);
}

static inline int cffmpeg_AVERROR_EINVAL(void) {
    return AVERROR(EINVAL);
}

static inline int cffmpeg_AVERROR_ENOMEM(void) {
    return AVERROR(ENOMEM);
}

static const int cffmpeg_AVERROR_BSF_NOT_FOUND     = AVERROR_BSF_NOT_FOUND;
static const int cffmpeg_AVERROR_BUG               = AVERROR_BUG;
static const int cffmpeg_AVERROR_BUFFER_TOO_SMALL   = AVERROR_BUFFER_TOO_SMALL;
static const int cffmpeg_AVERROR_DECODER_NOT_FOUND  = AVERROR_DECODER_NOT_FOUND;
static const int cffmpeg_AVERROR_DEMUXER_NOT_FOUND  = AVERROR_DEMUXER_NOT_FOUND;
static const int cffmpeg_AVERROR_ENCODER_NOT_FOUND  = AVERROR_ENCODER_NOT_FOUND;
static const int cffmpeg_AVERROR_EXIT               = AVERROR_EXIT;
static const int cffmpeg_AVERROR_EXTERNAL           = AVERROR_EXTERNAL;
static const int cffmpeg_AVERROR_FILTER_NOT_FOUND   = AVERROR_FILTER_NOT_FOUND;
static const int cffmpeg_AVERROR_INVALIDDATA        = AVERROR_INVALIDDATA;
static const int cffmpeg_AVERROR_MUXER_NOT_FOUND    = AVERROR_MUXER_NOT_FOUND;
static const int cffmpeg_AVERROR_OPTION_NOT_FOUND   = AVERROR_OPTION_NOT_FOUND;
static const int cffmpeg_AVERROR_PATCHWELCOME        = AVERROR_PATCHWELCOME;
static const int cffmpeg_AVERROR_PROTOCOL_NOT_FOUND  = AVERROR_PROTOCOL_NOT_FOUND;
static const int cffmpeg_AVERROR_STREAM_NOT_FOUND    = AVERROR_STREAM_NOT_FOUND;
static const int cffmpeg_AVERROR_UNKNOWN             = AVERROR_UNKNOWN;

// ---------- AV_NOPTS_VALUE ----------

static const int64_t cffmpeg_AV_NOPTS_VALUE = AV_NOPTS_VALUE;

// ---------- AV_TIME_BASE ----------

static const int cffmpeg_AV_TIME_BASE = AV_TIME_BASE;

static inline AVRational cffmpeg_AV_TIME_BASE_Q(void) {
    return AV_TIME_BASE_Q;
}

// ---------- av_err2str shim ----------
// The av_err2str macro uses a compound literal which Swift/C++ can't import.
// We use a thread-local buffer instead.

static inline const char *cffmpeg_av_err2str(int errnum) {
    static _Thread_local char buf[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(errnum, buf, sizeof(buf));
    return buf;
}

// ---------- Log levels ----------

static const int cffmpeg_AV_LOG_QUIET   = AV_LOG_QUIET;
static const int cffmpeg_AV_LOG_PANIC   = AV_LOG_PANIC;
static const int cffmpeg_AV_LOG_FATAL   = AV_LOG_FATAL;
static const int cffmpeg_AV_LOG_ERROR   = AV_LOG_ERROR;
static const int cffmpeg_AV_LOG_WARNING = AV_LOG_WARNING;
static const int cffmpeg_AV_LOG_INFO    = AV_LOG_INFO;
static const int cffmpeg_AV_LOG_VERBOSE = AV_LOG_VERBOSE;
static const int cffmpeg_AV_LOG_DEBUG   = AV_LOG_DEBUG;

// ---------- Rescale helpers ----------

static inline int64_t cffmpeg_av_rescale_q(int64_t a, AVRational bq, AVRational cq) {
    return av_rescale_q(a, bq, cq);
}

static inline int cffmpeg_av_compare_ts(int64_t ts_a, AVRational tb_a, int64_t ts_b, AVRational tb_b) {
    return av_compare_ts(ts_a, tb_a, ts_b, tb_b);
}

#endif // CFFMPEGSHIM_AVUTIL_SHIM_H
