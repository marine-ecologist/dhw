.onAttach <- function(libname, pkgname) {
  packageVersion <- utils::packageVersion(pkgname)
  packageStartupMessage(sprintf(" library(%s) dev v%s", pkgname, packageVersion))
}
