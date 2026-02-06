#ifndef CFFMPEGSHIM_AVFORMAT_SHIM_H
#define CFFMPEGSHIM_AVFORMAT_SHIM_H

#include <libavformat/avformat.h>
#include <libavformat/avio.h>

#include <stdint.h>

// ---------- Format flags ----------

static const int cffmpeg_AVFMT_NOFILE         = AVFMT_NOFILE;
static const int cffmpeg_AVFMT_GLOBALHEADER   = AVFMT_GLOBALHEADER;

// ---------- AVIO flags ----------

static const int cffmpeg_AVIO_FLAG_READ       = AVIO_FLAG_READ;
static const int cffmpeg_AVIO_FLAG_WRITE      = AVIO_FLAG_WRITE;
static const int cffmpeg_AVIO_FLAG_READ_WRITE = AVIO_FLAG_READ_WRITE;

// ---------- Seek flags ----------

static const int cffmpeg_AVSEEK_FLAG_BACKWARD = AVSEEK_FLAG_BACKWARD;
static const int cffmpeg_AVSEEK_FLAG_BYTE     = AVSEEK_FLAG_BYTE;
static const int cffmpeg_AVSEEK_FLAG_ANY      = AVSEEK_FLAG_ANY;
static const int cffmpeg_AVSEEK_FLAG_FRAME    = AVSEEK_FLAG_FRAME;

#endif // CFFMPEGSHIM_AVFORMAT_SHIM_H
