# utils.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

# %% rtemis_welcome ----
#' Startup message
#'
#' @param pkgname Character: Package name.
#' @param pkgversion Character: Package version.
#'
#' @return Character: The message.
#'
#' @keywords internal
#' @noRd
rtemis_welcome <- function(pkgname, pkgversion) {
  paste0(
    ".:",
    pkgname,
    " ",
    pkgversion,
    " \u00b7 ",
    utils::sessionInfo()[["platform"]]
  )
} # /rtemis.ml::rtemis_welcome
