# ============================================================
# _setup.R — central R path configuration (mirror of _setup.do).
# Source at the top of the R analysis scripts. Run R from the repository
# root:   source("code/_setup.R")
# ============================================================

# --- machine roots (per-machine; gitignored) ---
# code/paths.R defines root, data, datarepo, published, restricted, temp, code, output.
# Paths are resolved from the working directory, which must be the repository
# root (00_master.do cd's there before shell-calling R).
if (!exists("root")) source("code/paths.R")

proj <- data

# --- analysis-ready INPUT location: live working folders vs AEA deposit ---
# use_deposit 0 (default): read from the live "4 - Data processing" folders.
# use_deposit 1: read from the AEA deposit (published = author-owned; restricted = Ministry-owned).
if (!exists("use_deposit")) use_deposit <- 0

if (use_deposit == 0) {
  proc     <- file.path(data, "4 - Data processing")
  sampling <- file.path(proc, "Sampling")
  blclean  <- file.path(proc, "Baseline", "Clean")
  elclean  <- file.path(proc, "Endline", "Clean")
  eltemp   <- file.path(proc, "Endline", "Temp")
} else {
  sampling <- file.path(restricted, "sampling")
  blclean  <- file.path(published, "baseline")
  elclean  <- file.path(published, "endline")
  eltemp   <- file.path(temp, "endline")
}

# --- code OUTPUTS land in the repo (the paper reads from output/) ---
tabdir <- file.path(output, "tables")  # write tables here
figdir <- file.path(output, "plots")   # write figures here
