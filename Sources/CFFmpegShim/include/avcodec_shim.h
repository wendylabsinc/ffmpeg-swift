#ifndef CFFMPEGSHIM_AVCODEC_SHIM_H
#define CFFMPEGSHIM_AVCODEC_SHIM_H

#include <libavcodec/avcodec.h>
#include <libavcodec/codec.h>
#include <libavcodec/codec_id.h>
#include <libavcodec/codec_par.h>
#include <libavcodec/packet.h>

#include <stdint.h>

// ---------- Codec capability flags ----------

static const int cffmpeg_AV_CODEC_CAP_DRAW_HORIZ_BAND  = AV_CODEC_CAP_DRAW_HORIZ_BAND;
static const int cffmpeg_AV_CODEC_CAP_DR1              = AV_CODEC_CAP_DR1;
static const int cffmpeg_AV_CODEC_CAP_DELAY            = AV_CODEC_CAP_DELAY;
static const int cffmpeg_AV_CODEC_CAP_SMALL_LAST_FRAME = AV_CODEC_CAP_SMALL_LAST_FRAME;
static const int cffmpeg_AV_CODEC_CAP_SUBFRAMES        = AV_CODEC_CAP_SUBFRAMES;
static const int cffmpeg_AV_CODEC_CAP_EXPERIMENTAL     = AV_CODEC_CAP_EXPERIMENTAL;
static const int cffmpeg_AV_CODEC_CAP_CHANNEL_CONF     = AV_CODEC_CAP_CHANNEL_CONF;
static const int cffmpeg_AV_CODEC_CAP_FRAME_THREADS    = AV_CODEC_CAP_FRAME_THREADS;
static const int cffmpeg_AV_CODEC_CAP_SLICE_THREADS    = AV_CODEC_CAP_SLICE_THREADS;
static const int cffmpeg_AV_CODEC_CAP_VARIABLE_FRAME_SIZE = AV_CODEC_CAP_VARIABLE_FRAME_SIZE;
static const int cffmpeg_AV_CODEC_CAP_AVOID_PROBING    = AV_CODEC_CAP_AVOID_PROBING;
static const int cffmpeg_AV_CODEC_CAP_HARDWARE         = AV_CODEC_CAP_HARDWARE;
static const int cffmpeg_AV_CODEC_CAP_HYBRID           = AV_CODEC_CAP_HYBRID;
static const int cffmpeg_AV_CODEC_CAP_ENCODER_REORDERED_OPAQUE = AV_CODEC_CAP_ENCODER_REORDERED_OPAQUE;

// ---------- Codec flags ----------

static const int cffmpeg_AV_CODEC_FLAG_GLOBAL_HEADER = AV_CODEC_FLAG_GLOBAL_HEADER;

// ---------- Packet flags ----------

static const int cffmpeg_AV_PKT_FLAG_KEY     = AV_PKT_FLAG_KEY;
static const int cffmpeg_AV_PKT_FLAG_CORRUPT = AV_PKT_FLAG_CORRUPT;

#endif // CFFMPEGSHIM_AVCODEC_SHIM_H
