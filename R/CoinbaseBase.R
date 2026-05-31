# File: R/CoinbaseBase.R
# Abstract R6 base class for all Coinbase API client classes.

#' CoinbaseBase: Abstract Base Class for Coinbase API Clients
#'
#' Provides shared infrastructure for all Coinbase R6 classes, including API
#' credential management, sync/async execution mode, and a standardised method
#' for executing API requests through the single [coinbase_build_request()]
#' funnel.
#'
#' ### Sync vs Async
#' The `async` parameter controls execution mode for all API methods:
#' - `async = FALSE` (default): methods return results directly.
#' - `async = TRUE`: methods return [promises::promise] objects that resolve to
#'   the same types.
#'
#' Async mode requires the `promises` and `later` packages (both `Suggests`).
#' Consume promises with [coro::async()] and `await()` or [promises::then()],
#' and drive the event loop with `later::run_now()` (e.g.
#' `while (!later::loop_empty()) later::run_now()`).
#'
#' ### Hosts
#' Coinbase splits across two hosts. Authenticated trading and account endpoints
#' live on the Advanced Trade host ([get_base_url()],
#' `https://api.coinbase.com`); the public market-data endpoints with deep
#' history live on the Exchange host ([get_exchange_base_url()],
#' `https://api.exchange.coinbase.com`). Subclasses select the host per request
#' via the `base_url` argument of `private$.request()`.
#'
#' ### Design
#' This class is not meant to be instantiated directly. Subclasses (e.g.
#' `CoinbaseMarketData`, `CoinbaseTrading`) inherit from it and define public
#' methods that delegate to `private$.request()`.
#'
#' @section Fields:
#' All fields are private:
#' - `.keys`: List; API credentials from [get_api_keys()].
#' - `.base_url`: Character; Advanced Trade API base URL.
#' - `.exchange_base_url`: Character; Exchange API base URL.
#' - `.perform`: Function; either [httr2::req_perform] or [httr2::req_perform_promise].
#' - `.is_async`: Logical; whether the instance is in async mode.
#'
#' @importFrom R6 R6Class
#' @importFrom httr2 req_perform
#' @export
CoinbaseBase <- R6::R6Class(
  "CoinbaseBase",
  public = list(
    #' @description
    #' Initialise a CoinbaseBase object.
    #'
    #' @param keys List; API credentials from [get_api_keys()]. Defaults to
    #'   `get_api_keys()`.
    #' @param base_url Character; Advanced Trade API base URL. Defaults to
    #'   `get_base_url()`.
    #' @param exchange_base_url Character; Exchange API base URL. Defaults to
    #'   `get_exchange_base_url()`.
    #' @param async Logical; if `TRUE`, methods return promises. Default `FALSE`.
    #' @return Invisible self.
    initialize = function(
      keys = get_api_keys(),
      base_url = get_base_url(),
      exchange_base_url = get_exchange_base_url(),
      async = FALSE
    ) {
      private$.keys <- keys
      private$.base_url <- base_url
      private$.exchange_base_url <- exchange_base_url
      private$.is_async <- isTRUE(async)

      if (private$.is_async) {
        missing <- Filter(function(p) !requireNamespace(p, quietly = TRUE), c("promises", "later"))
        if (length(missing) > 0) {
          rlang::abort(paste0(
            "Async mode requires the package(s) ",
            paste(sprintf("'%s'", missing), collapse = " and "),
            ". Install with: install.packages(c(",
            paste(sprintf("'%s'", missing), collapse = ", "),
            "))"
          ))
        }
        private$.perform <- httr2::req_perform_promise
      } else {
        private$.perform <- httr2::req_perform
      }

      return(invisible(self))
    }
  ),
  active = list(
    #' @field is_async Logical; read-only flag indicating whether this instance
    #'   operates in async mode.
    is_async = function() {
      return(private$.is_async)
    }
  ),
  private = list(
    .keys = NULL,
    .base_url = NULL,
    .exchange_base_url = NULL,
    .perform = NULL,
    .is_async = FALSE,

    # Execute a Coinbase API Request
    #
    # Convenience wrapper around coinbase_build_request() that injects the
    # instance's base URL, credentials, and perform function. Accepts a .parser
    # callback so subclass methods define their data transformation without any
    # sync/async awareness.
    #
    # `auth = TRUE` signs the request with the instance's credentials.
    # `base_url = NULL` uses the Advanced Trade host; pass the Exchange host for
    # public market-data endpoints.
    .request = function(
      endpoint,
      method = "GET",
      query = list(),
      body = NULL,
      auth = TRUE,
      .parser = identity,
      timeout = 30,
      base_url = NULL
    ) {
      effective_base <- private$.base_url
      if (!is.null(base_url)) {
        effective_base <- base_url
      }
      return(coinbase_build_request(
        base_url = effective_base,
        endpoint = endpoint,
        method = method,
        query = query,
        body = body,
        keys = {
          keys <- NULL
          if (auth) {
            keys <- private$.keys
          }
          keys
        },
        .perform = private$.perform,
        .parser = .parser,
        is_async = private$.is_async,
        timeout = timeout
      ))
    }
  )
)
