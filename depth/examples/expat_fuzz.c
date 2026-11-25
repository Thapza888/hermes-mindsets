/* libFuzzer harness — expat XML parser, chunked input, DTD + namespace paths live.
 * Consumes the parse result: XML_GetIdAttributeIndex is read on every start tag
 * (the pre-2.11 uninitialised-field surface) and the returned status steers control. */
#include <stddef.h>
#include <string.h>
#include "expat.h"

static volatile int sink;

static void XMLCALL on_start(void *ud, const XML_Char *name, const XML_Char **atts) {
  size_t n = atts ? (size_t)(atts[0] != 0) : 0;
  int idx = XML_GetIdAttributeIndex((XML_Parser)ud);
  sink = idx + (int)n + (int)strlen(name);
}

static void XMLCALL on_entity_decl(void *ud, const XML_Char *e, int is_pe,
                                   const XML_Char *v, int vlen, const XML_Char *b,
                                   const XML_Char *sysid, const XML_Char *pubid,
                                   const XML_Char *ndata) {
  sink = (int)strlen(e) + vlen + (b != 0) + is_pe
         + (sysid != 0) + (pubid != 0) + (ndata != 0);
}

static int XMLCALL on_ext_entity(XML_Parser p, const XML_Char *ctx, const XML_Char *base,
                                 const XML_Char *sysid, const XML_Char *pubid) {
  (void)p; (void)ctx; (void)base; (void)sysid; (void)pubid;
  return XML_STATUS_OK;
}

int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
  XML_Parser p = XML_ParserCreate(NULL);
  if (!p) return 0;
  XML_SetUserData(p, p);
  XML_SetStartElementHandler(p, on_start);
  XML_SetEntityDeclHandler(p, on_entity_decl);
  XML_SetExternalEntityRefHandler(p, on_ext_entity);
  XML_SetParamEntityParsing(p, XML_PARAM_ENTITY_PARSING_ALWAYS);

  size_t off = 0;
  int ok = 1;
  while (off < size) {
    size_t chunk = 1 + ((size - off) % 97);
    if (chunk > size - off) chunk = size - off;
    if (XML_Parse(p, (const char *)data + off, (int)chunk, 0) != XML_STATUS_OK) {
      /* an error path: keep reading the error surface, that is where leaks live */
      sink = XML_GetErrorCode(p) + (int)XML_GetCurrentByteIndex(p);
      ok = 0;
      break;
    }
    off += chunk;
  }
  if (ok) {
    XML_Parse(p, "", 0, 1);
  } else {
    XML_Parse(p, "", 0, 1); /* finalise after error, then free */
  }
  XML_ParserFree(p);
  return 0;
}
