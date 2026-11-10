# config.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

# Writes src/Makevars (or src/Makevars.win) from its template, replacing each
# @PLACEHOLDER@ with the value of the corresponding variable whose name starts
# with `.` (for example @CRAN_FLAGS@ with `.cran_flags`).

# Checks the Rust toolchain against SystemRequirements.
source("tools/msrv.R")

# Build mode from the DEBUG and NOT_CRAN environment variables.
env_debug <- Sys.getenv("DEBUG")
env_not_cran <- Sys.getenv("NOT_CRAN")

# Vendored crates enable an offline build.
vendor_exists <- file.exists("src/rust/vendor.tar.xz")

is_not_cran <- env_not_cran != ""
is_debug <- env_debug != ""

if (is_debug) {
  # A debug build is never a CRAN build; CRAN builds use the release profile.
  is_not_cran <- TRUE
  message("Creating DEBUG build.")
}

if (!is_not_cran) {
  message("Building for CRAN.")
}

# CRAN builds (NOT_CRAN unset) with vendored crates run offline on at most two
# jobs.
.cran_flags <- ifelse(
  !is_not_cran && vendor_exists,
  "-j 2 --offline",
  ""
)

# RTEMIS_CRATE_PATH, when set, points to a local checkout of the `rtemis`
# crate (for example /path/to/rtemis-rs/crates/rtemis). Cargo then builds against
# that source in place of the crates.io release named in Cargo.toml. CRAN
# builds leave it unset.
crate_path <- Sys.getenv("RTEMIS_CRATE_PATH")
.cargo_config <- if (nzchar(crate_path)) {
  crate_path <- normalizePath(crate_path, winslash = "/", mustWork = TRUE)
  message("Using the rtemis crate at ", crate_path, ".")
  sprintf("--config 'patch.crates-io.rtemis.path=\"%s\"'", crate_path)
} else {
  ""
}

# DEBUG selects the dev profile; otherwise the release profile.
.profile <- ifelse(is_debug, "", "--release")
.clean_targets <- ifelse(is_debug, "", "$(TARGET_DIR)")

# Target triple of webR.
webr_target <- "wasm32-unknown-emscripten"

# TRUE when R runs as webR.
is_wasm <- identical(R.version$platform, webr_target)

if (is_wasm) {
  message("Building for WebR")
}

# Library directory under the target directory: [<webR target>/]<debug|release>,
# for @LIBDIR@.
target_libpath <- if (is_wasm) "wasm32-unknown-emscripten" else NULL
cfg <- if (is_debug) "debug" else "release"

.libdir <- paste(c(target_libpath, cfg), collapse = "/")

# @TARGET@: an explicit --target for webR builds only.
.target <- ifelse(is_wasm, paste0("--target=", webr_target), "")

# WebAssembly builds abort on panic.
.panic_exports <- ifelse(
  is_wasm,
  "CARGO_PROFILE_DEV_PANIC=\"abort\" CARGO_PROFILE_RELEASE_PANIC=\"abort\" ",
  ""
)

# Template and output for the current platform.
is_windows <- .Platform[["OS.type"]] == "windows"

mv_fp <- ifelse(
  is_windows,
  "src/Makevars.win.in",
  "src/Makevars.in"
)

mv_ofp <- ifelse(
  is_windows,
  "src/Makevars.win",
  "src/Makevars"
)

# The output is rewritten on every configure run.
if (file.exists(mv_ofp)) {
  message("Cleaning previous `", mv_ofp, "`.")
  invisible(file.remove(mv_ofp))
}

mv_txt <- readLines(mv_fp)

new_txt <- gsub("@CRAN_FLAGS@", .cran_flags, mv_txt) |>
  gsub("@CARGO_CONFIG@", .cargo_config, x = _, fixed = TRUE) |>
  gsub("@PROFILE@", .profile, x = _) |>
  gsub("@CLEAN_TARGET@", .clean_targets, x = _) |>
  gsub("@LIBDIR@", .libdir, x = _) |>
  gsub("@TARGET@", .target, x = _) |>
  gsub("@PANIC_EXPORTS@", .panic_exports, x = _)

message("Writing `", mv_ofp, "`.")
con <- file(mv_ofp, open = "wb")
writeLines(new_txt, con, sep = "\n")
close(con)

message("`tools/config.R` has finished.")
