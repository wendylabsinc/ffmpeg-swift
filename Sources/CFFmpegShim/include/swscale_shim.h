#ifndef CFFMPEGSHIM_SWSCALE_SHIM_H
#define CFFMPEGSHIM_SWSCALE_SHIM_H

#include <libswscale/swscale.h>

#include <stdint.h>

// ---------- Scaling algorithm flags ----------

static const int cffmpeg_SWS_FAST_BILINEAR = SWS_FAST_BILINEAR;
static const int cffmpeg_SWS_BILINEAR      = SWS_BILINEAR;
static const int cffmpeg_SWS_BICUBIC       = SWS_BICUBIC;
static const int cffmpeg_SWS_POINT         = SWS_POINT;
static const int cffmpeg_SWS_AREA          = SWS_AREA;
static const int cffmpeg_SWS_BICUBLIN      = SWS_BICUBLIN;
static const int cffmpeg_SWS_LANCZOS       = SWS_LANCZOS;

#endif // CFFMPEGSHIM_SWSCALE_SHIM_H
