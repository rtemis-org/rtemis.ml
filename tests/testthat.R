# testthat.R
# ::rtemis.ml::
# 2026- EDG rtemis.org

# Runs the tests in tests/testthat during R CMD check.

library(testthat)
library(rtemis.ml)

test_check("rtemis.ml")
