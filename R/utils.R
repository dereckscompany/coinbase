# File: R/utils.R
# General utility functions for the coinbase package: base URLs and credentials.

#' Retrieve Coinbase Advanced Trade API Base URL
#'
#' Returns the base URL for the Coinbase Advanced Trade API (trading, account,
#' and authenticated endpoints) in the following priority:
#' 1. The explicitly provided `url` parameter.
#' 2. The `COINBASE_API_ENDPOINT` environment variable.
#' 3. The default `"https://api.coinbase.com"`.
#'
#' @param url Character string; explicit base URL. Defaults to
#'   `Sys.getenv("COINBASE_API_ENDPOINT")`.
#' @return Character string; the API base URL.
#'
#' @examples
#' \dontrun{
#' get_base_url()
#' }
#' @export
get_base_url <- function(url = Sys.getenv("COINBASE_API_ENDPOINT")) {
  if (is.null(url) || !nzchar(url)) {
    return("https://api.coinbase.com")
  }
  return(url)
}

#' Retrieve Coinbase Exchange API Base URL
#'
#' Returns the base URL for the Coinbase Exchange API in the following priority:
#' 1. The explicitly provided `url` parameter.
#' 2. The `COINBASE_EXCHANGE_API_ENDPOINT` environment variable.
#' 3. The default `"https://api.exchange.coinbase.com"`.
#'
#' The Exchange API hosts the public market-data endpoints (e.g. full trade
#' history paginated back to a product's inception) that the Advanced Trade host
#' does not expose. These endpoints require no authentication.
#'
#' @param url Character string; explicit base URL. Defaults to
#'   `Sys.getenv("COINBASE_EXCHANGE_API_ENDPOINT")`.
#' @return Character string; the Exchange API base URL.
#'
#' @examples
#' \dontrun{
#' get_exchange_base_url()
#' }
#' @export
get_exchange_base_url <- function(url = Sys.getenv("COINBASE_EXCHANGE_API_ENDPOINT")) {
  if (is.null(url) || !nzchar(url)) {
    return("https://api.exchange.coinbase.com")
  }
  return(url)
}

#' Retrieve Coinbase API Credentials
#'
#' Fetches Coinbase Advanced Trade (CDP) API credentials from environment
#' variables or explicit arguments. Credentials are created at
#' <https://www.coinbase.com/settings/api> and downloaded as a JSON file
#' containing a `name` and a `privateKey`.
#'
#' Required environment variables: `COINBASE_API_KEY_NAME`,
#' `COINBASE_API_PRIVATE_KEY`.
#'
#' ### Private key formatting
#' The downloaded `privateKey` is a multi-line value. To store it on a single
#' line in `.Renviron`, escape the newlines as the two characters `\\n`; this
#' function unescapes them back to real newlines before use. Both EC
#' (`-----BEGIN EC PRIVATE KEY-----`, signed with ES256) and base64-encoded
#' Ed25519 keys (signed with EdDSA) are supported by the signer.
#'
#' @param api_key_name Character string; the credential `name`, e.g.
#'   `"organizations/<org-uuid>/apiKeys/<key-uuid>"`. Defaults to
#'   `Sys.getenv("COINBASE_API_KEY_NAME")`.
#' @param api_private_key Character string; the credential `privateKey`.
#'   Defaults to `Sys.getenv("COINBASE_API_PRIVATE_KEY")`.
#' @return Named list with `api_key_name` and `api_private_key` (newlines
#'   unescaped).
#'
#' @examples
#' \dontrun{
#' keys <- get_api_keys()
#' }
#' @export
get_api_keys <- function(
  api_key_name = Sys.getenv("COINBASE_API_KEY_NAME"),
  api_private_key = Sys.getenv("COINBASE_API_PRIVATE_KEY")
) {
  if (!nzchar(api_key_name) || !nzchar(api_private_key)) {
    rlang::warn(
      "Coinbase API credentials are empty. Set COINBASE_API_KEY_NAME and COINBASE_API_PRIVATE_KEY environment variables or pass them explicitly."
    )
  }
  # `.Renviron` stores the PEM on one line with literal "\n"; restore newlines.
  api_private_key <- gsub("\\\\n", "\n", api_private_key)
  return(list(
    api_key_name = api_key_name,
    api_private_key = api_private_key
  ))
}
