/* minimal hand-written expat_config.h for a standalone fuzz build (macOS/arm64) */
#ifndef EXPAT_CONFIG_H
#define EXPAT_CONFIG_H

#define BYTEORDER 1234
#define HAVE_DLFCN_H 1
#define HAVE_FCNTL_H 1
#define HAVE_GETPAGESIZE 1
#define HAVE_INTTYPES_H 1
#define HAVE_MEMORY_H 1
#define HAVE_MMAP 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_ARC4RANDOM 1
#define HAVE_ARC4RANDOM_BUF 1
#define STDC_HEADERS 1

#define XML_CONTEXT_BYTES 1024
#define XML_DTD 1
#define XML_GE 1
#define XML_NS 1

#endif /* EXPAT_CONFIG_H */
