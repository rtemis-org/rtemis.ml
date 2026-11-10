# rust-attribution.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

# Writes LICENSE.note and inst/AUTHORS: the name, version, authors, license,
# and repository of every Rust crate compiled into the package, read from
# `cargo metadata` of src/rust with the versions locked in Cargo.lock.
# `just vendor` runs it after vendoring; it runs from the package root.

# %% Crates without an authors field ----
# Copyright holders as stated in each crate's license.
crate_authors <- c(
  "extendr-api" = "The extendr contributors",
  "extendr-ffi" = "The extendr contributors",
  "extendr-macros" = "The extendr contributors",
  "rtemis" = "E.D. Gennatas"
)

# %% License notices ----
# MIT requires its copyright and permission notice in every copy. The extendr
# crates ship no license file, so the vendored archive omits the notice and
# LICENSE.note carries it, verbatim from the extendr repository.
notices <- list(
  list(
    crates = c("extendr-api", "extendr-ffi", "extendr-macros"),
    file = "tools/notices/extendr-LICENSE"
  )
)

# %% Crate metadata ----
meta_json <- system2(
  "cargo",
  c(
    "metadata",
    "--format-version",
    "1",
    "--locked",
    "--manifest-path",
    "src/rust/Cargo.toml"
  ),
  stdout = TRUE
)
meta <- jsonlite::fromJSON(
  paste(meta_json, collapse = "\n"),
  simplifyVector = FALSE
)
resolved <- vapply(meta[["resolve"]][["nodes"]], `[[`, "", "id")
root <- meta[["resolve"]][["root"]]
crates <- Filter(
  function(p) p[["id"]] %in% resolved && p[["id"]] != root,
  meta[["packages"]]
)
crates <- crates[order(
  vapply(crates, `[[`, "", "name"),
  vapply(crates, `[[`, "", "version")
)]

# Authors without email addresses; `crate_authors` where the manifest lists none.
authors_of <- function(p) {
  a <- unlist(p[["authors"]])
  if (length(a) == 0L) {
    a <- crate_authors[[p[["name"]]]]
    if (is.null(a)) {
      stop("No authors for crate '", p[["name"]], "': add it to crate_authors.")
    }
  }
  paste(trimws(sub("<[^>]*>", "", a)), collapse = ", ")
}

# %% LICENSE.note ----
rule <- strrep("-", 72L)
entries <- unlist(lapply(crates, function(p) {
  c(
    paste0("Name:        ", p[["name"]]),
    paste0("Version:     ", p[["version"]]),
    paste0("Authors:     ", authors_of(p)),
    paste0("License:     ", p[["license"]]),
    paste0(
      "Repository:  ",
      if (is.null(p[["repository"]])) "" else p[["repository"]]
    ),
    ""
  )
}))
notice_text <- unlist(lapply(notices, function(n) {
  c(
    rule,
    paste0("License notice of ", paste(n[["crates"]], collapse = ", "), ":"),
    "",
    readLines(n[["file"]], warn = FALSE),
    ""
  )
}))
writeLines(
  c(
    "The compiled code of rtemis.ml includes the following Rust crates, bundled",
    "as source in src/rust/vendor.tar.xz. The license files that a crate ships",
    "are part of that archive; the notices of crates that ship none follow the",
    "list.",
    "",
    rule,
    "",
    entries,
    notice_text
  ),
  "LICENSE.note"
)

# %% inst/AUTHORS ----
dir.create("inst", showWarnings = FALSE)
writeLines(
  c(
    "Authors of the Rust crates compiled into rtemis.ml and bundled as source in",
    "src/rust/vendor.tar.xz. Licenses and repositories: LICENSE.note.",
    "",
    vapply(
      crates,
      function(p) paste0(p[["name"]], " ", p[["version"]], ": ", authors_of(p)),
      ""
    )
  ),
  "inst/AUTHORS"
)
message(
  "Wrote LICENSE.note and inst/AUTHORS for ",
  length(crates),
  " crates."
)
