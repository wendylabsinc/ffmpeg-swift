#ifndef CFFMPEGSHIM_AVFILTER_SHIM_H
#define CFFMPEGSHIM_AVFILTER_SHIM_H

#include <libavfilter/avfilter.h>
#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>

#include <stdint.h>

// ---------- Buffer source flags ----------

static const int cffmpeg_AV_BUFFERSRC_FLAG_KEEP_REF = AV_BUFFERSRC_FLAG_KEEP_REF;
static const int cffmpeg_AV_BUFFERSRC_FLAG_NO_CHECK_FORMAT = AV_BUFFERSRC_FLAG_NO_CHECK_FORMAT;
static const int cffmpeg_AV_BUFFERSRC_FLAG_PUSH = AV_BUFFERSRC_FLAG_PUSH;

#endif // CFFMPEGSHIM_AVFILTER_SHIM_H
