# expat — dead paths

| surface | why it died | time |
|---|---|---|
| tag-level backport gap | master 6 commits ahead of R_2_11_0, all non-security; every recent fix present in both | 15:02 |
| R_2_7_x missing 98b5ec1e (m_idAttIndex init) | 2.7 line is security-only maintenance; a behaviour fix not landing there is by design, not a gap. Minor info leak at best | 15:10 |
| XML_ParserReset harness reuse | measured 111 exec/s vs 137 create/free — reset re-allocates more than it saves | 15:14 |
| SDK expat.h | macOS SDK header predates GetCurrentByteIndex64; must -I the project's lib dir | 15:16 |
| strlen() on EntityDeclHandler value | not NUL-terminated; reported a harness-side heap overflow on `<!ENTITY e "v">` | 15:08 |
