# expat — surface map

repo: https://github.com/libexpat/libexpat (expat/, C, ~11k LOC in xmlparse.c)
why: dense (22 CVEs/12mo per Sorona program sort), no-bounty rail, pure parser, white-box
branches: master only (release via tags R_2_x_y; 2.7.x line is security-maintained, last tag R_2_7_5 2026-03-17)

## backport state (toolchain/secgit.sh)
master is 6 commits ahead of R_2_11_0, none security-shaped. Every recent security fix
(attIndex overflow, nPrefixes overflow, XML_ParseBuffer len check, expat_realloc overflow,
encoding-decoder overread) is in R_2_11_0 and master. No live gap at tag level.

## entry points
XML_Parse / XML_Parse64 / XML_ParseBuffer (chunked + final), XML_GetBuffer,
XML_ExternalEntityParserCreate, XML_SetEncoding, unknown-encoding converters.

## sinks (honest state: expat has been OSS-Fuzz'd for years)
m_buffer realloc + memcpy in doContent/storeAtts; attIndex / nPrefixes int arithmetic;
m_idAttIndex (uninit pre-2.11, fixed 98b5ec1e); entity expansion budget; hash table
lookup/grow; m_eventPtr / m_positionPtr pairing after error and after final parse.

## harness
harness/expat_fuzz.c — chunked feed (1..97 byte chunks), DTD + namespaces live,
external entities stubbed to OK, start-tag handler reads XML_GetIdAttributeIndex,
volatile sink consumes it. Rejected: XML_ParserReset reuse (111/s vs 137/s, measured).

## build
CC=/opt/homebrew/opt/llvm/bin/clang
SRCS="lib/xmlparse.c lib/xmltok.c lib/xmlrole.c lib/xcs.c lib/random_arc4random_buf.c"
EXTRA_CFLAGS="-Ibuild -Ilib"   (build/expat_config.h is hand-written; no cmake on this box)

## state
campaign running. No crashes in 20k+ execs at 326–470/s. Expected on this target.

## campaign log
241 s @ 567 exec/s, 136,666 execs, 4350 new units, **0 crashes**. Corpus 328 MB (needs -max_len).
Verdict: expat is maturity-bound — a mature OSS-Fuzz target will not fall to a 4-minute campaign.
The engine is proven; the next target should be an *unfuzzed* parser (vector B, the real gap), not
a dense-but-fuzzed one.
