# ============================================================
# paths_example.R — TEMPLATE for per-machine R path globals.
# Copy this file to paths.R (same folder) and edit for your machine.
# paths.R is gitignored; this template is tracked. Mirror of paths.do.
# Forward slashes always, even on Windows. Run R from the repository root.
# ============================================================

# Repository root (the folder containing code/, output/)
root <- "[EDIT]/psp"

# Confidential project data root (never tracked)
data <- "[EDIT]/DiD - Morocco Pioneer School"

# Analysis-ready data, split by who may share it (confidential; not tracked)
datarepo   <- file.path(data, "4 - Data processing", "Data repository")
published  <- file.path(datarepo, "data", "published")    # author-collected primary data (may be shared, after deidentification)
restricted <- file.path(datarepo, "data", "restricted")   # Ministry-owned administrative data (Data Editor only, under agreement)
temp       <- file.path(datarepo, "temp")                 # regenerable intermediates

# Derived (usually no edit needed)
code   <- file.path(root, "code")
output <- file.path(root, "output")
