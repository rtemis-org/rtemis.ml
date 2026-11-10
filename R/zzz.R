# zzz.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

pkgversion <- utils::packageVersion("rtemis.ml")

.onAttach <- function(libname, pkgname) {
  if (interactive()) {
    packageStartupMessage(
      rtemis_welcome(pkgname = pkgname, pkgversion = pkgversion)
    )
  }
}
