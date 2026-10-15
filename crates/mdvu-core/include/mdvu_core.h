#ifndef MDVU_CORE_H
#define MDVU_CORE_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MdvuDocument MdvuDocument;

/**
 * Returns the version string of mdvu-core (e.g. "0.4.1").
 */
const char* mdvu_version(void);

/**
 * Returns decompressed Mermaid JS engine string (cached in memory).
 */
const char* mdvu_get_mermaid_js(void);

/**
 * Returns decompressed PlantUML JS engine string (cached in memory).
 */
const char* mdvu_get_plantuml_js(void);

/**
 * Returns decompressed KaTeX JS engine string (cached in memory).
 */
const char* mdvu_get_katex_js(void);

/**
 * Renders a Markdown string to a complete HTML document.
 * 
 * @param source Null-terminated UTF-8 markdown source.
 * @param title_override Optional document title override (NULL to auto-detect from first h1).
 * @param dialect_str Markdown dialect name ("generic", "obsidian", "mkdocs", "gfm", etc. or NULL).
 * @param theme_str Color theme ("light", "dark", "system" or NULL).
 * @param full_width Whether to apply full-width article styling.
 * @param base_url Optional base URL for resolving relative links and images.
 * @param embed_engines Whether to decompress and inline KaTeX, Mermaid, and PlantUML JS engines.
 * @return An allocated MdvuDocument pointer, which MUST be freed with mdvu_document_free().
 */
MdvuDocument* mdvu_render_to_html(
    const char* source,
    const char* title_override,
    const char* dialect_str,
    const char* theme_str,
    bool full_width,
    const char* base_url,
    bool embed_engines
);

/**
 * Retrieves the generated HTML string from an MdvuDocument.
 * The pointer is valid until mdvu_document_free is called.
 */
const char* mdvu_document_get_html(const MdvuDocument* doc);

/**
 * Retrieves the raw HTML body (inner article content) from an MdvuDocument.
 * The pointer is valid until mdvu_document_free is called.
 */
const char* mdvu_document_get_body(const MdvuDocument* doc);

/**
 * Retrieves the document title from an MdvuDocument.
 * The pointer is valid until mdvu_document_free is called.
 */
const char* mdvu_document_get_title(const MdvuDocument* doc);

/**
 * Retrieves the JSON string containing table-of-contents entries.
 * The pointer is valid until mdvu_document_free is called.
 */
const char* mdvu_document_get_toc_json(const MdvuDocument* doc);

/**
 * Returns true if the rendered document contains Mermaid diagrams.
 */
bool mdvu_document_has_mermaid(const MdvuDocument* doc);

/**
 * Returns true if the rendered document contains PlantUML diagrams.
 */
bool mdvu_document_has_plantuml(const MdvuDocument* doc);

/**
 * Returns true if the rendered document contains Math formulas.
 */
bool mdvu_document_has_math(const MdvuDocument* doc);

/**
 * Frees an MdvuDocument allocated by mdvu_render_to_html().
 */
void mdvu_document_free(MdvuDocument* doc);

#ifdef __cplusplus
}
#endif

#endif /* MDVU_CORE_H */
