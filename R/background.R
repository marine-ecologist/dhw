#' @title Run Expression in Background with Completion Message
#' @name background
#' @description
#' Launches a background R process to run an expression asynchronously.
#' Displays a message once the process finishes.
#'
#' @param expr An expression wrapped in `{}` to be evaluated in a background R process.
#' @param stdout Optional file to capture standard output. Defaults to NULL.
#' @param stderr Optional file to capture standard error. Defaults to NULL.
#' @param wait Logical, if TRUE will block until process is complete and print message. Default: TRUE.
#'
#' @return A `callr::process` object.
#'
#' @examples
#' \dontrun{
#' background({
#'   Sys.sleep(5)
#'   writeLines("Done", "output3.txt")
#' })
#' }
background <- function(expr,
                       stdout = NULL,
                       stderr = NULL,
                       overwrite = TRUE,
                       envir = .GlobalEnv) {

  expr_sub <- substitute(expr)
  tmpfile <- tempfile(fileext = ".rds")

  pkgs <- setdiff(loadedNamespaces(), c("base", "stats", "graphics", "grDevices", "utils", "datasets", "methods", "tools"))

  proc <- callr::r_bg(
    function(expr_inner, pkgs, savefile) {
      for (pkg in pkgs) suppressMessages(library(pkg, character.only = TRUE))
      local_env <- new.env()
      eval(expr_inner, envir = local_env)
      save_list <- as.list(local_env)
      saveRDS(save_list, savefile)
    },
    args = list(expr_inner = expr_sub, pkgs = pkgs, savefile = tmpfile),
    stdout = stdout,
    stderr = stderr
  )

  proc$wait()  # always wait silently

  if (proc$get_exit_status() == 0 && file.exists(tmpfile)) {
    objlist <- readRDS(tmpfile)

    existing <- intersect(names(objlist), ls(envir = envir))
    if (length(existing) > 0 && !overwrite) {
      warning("Objects not assigned due to conflict: ", paste(existing, collapse = ", "))
      objlist <- objlist[setdiff(names(objlist), existing)]
    }

    list2env(objlist, envir = envir)
    return(invisible(objlist))
  } else {
    warning("Background process failed or no results returned.")
    return(invisible(NULL))
  }
}
