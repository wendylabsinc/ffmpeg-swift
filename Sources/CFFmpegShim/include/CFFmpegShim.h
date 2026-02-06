#ifndef CFFMPEGSHIM_H
#define CFFMPEGSHIM_H

// Umbrella header for CFFmpegShim.
// This pulls in all FFmpeg headers via shim wrappers that expose
// C macros as Swift-importable constants and inline functions.

#include "avutil_shim.h"
#include "avcodec_shim.h"
#include "avformat_shim.h"
#include "avfilter_shim.h"
#include "swscale_shim.h"
#include "swresample_shim.h"

#endif // CFFMPEGSHIM_H
