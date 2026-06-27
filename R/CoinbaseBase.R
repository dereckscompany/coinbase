# File: R/CoinbaseBase.R
# Abstract R6 base class for all Coinbase API client classes. Inherits the
# generic transport (sync/async funnel, retry, throttle) from
# connectcore::RestClient and plugs in the two Coinbase-specific seams: JWT
# signing (.sign) and the Coinbase error/empty-body envelope (.parse_envelope).

#' CoinbaseBase: Abstract Base Class for Coinbase API Clients
#'
#' Provides shared infrastructure for all Coinbase R6 classes by extending
#' [connectcore::RestClient]. It inherits the single `private$.request()` funnel
#' (mode-transparent sync/async, NULL-field stripping, retry/throttle) and
#' customises only the two venue-specific seams:
#' - `.sign()` — attaches a Coinbase JWT (ES256 / EdDSA) to each authenticated
#'   request (via the internal `coinbase_jwt_sign()`).
#' - `.parse_envelope()` — reads the Coinbase error envelope and tolerates the
#'   empty success bodies some endpoints return (via the internal
#'   `parse_coinbase_response()`).
#'
#' ### Sync vs Async
#' The `async` parameter controls execution mode for all API methods:
#' - `async = FALSE` (default): methods return results directly.
#' - `async = TRUE`: methods return [promises::promise] objects that resolve to
#'   the same types.
#'
#' Async mode requires the `promises` package (a `Suggests`). Consume promises
#' with [coro::async()] and `await()` or [promises::then()]; to drive the event
#' loop in a script use the (optional) `later` package, e.g.
#' `while (!later::loop_empty()) later::run_now()`.
#'
#' ### Hosts
#' Coinbase splits across two hosts. Authenticated trading and account endpoints
#' live on the Advanced Trade host ([get_base_url()],
#' `https://api.coinbase.com`); the public market-data endpoints with deep
#' history live on the Exchange host ([get_exchange_base_url()],
#' `https://api.exchange.coinbase.com`). Subclasses select the host per request
#' via the `base_url` argument of `private$.request()` (this class extends the
#' connectcore funnel with that argument).
#'
#' ### Design
#' This class is not meant to be instantiated directly. Subclasses (e.g.
#' `CoinbaseMarketData`, `CoinbaseTrading`) inherit from it and define public
#' methods that delegate to `private$.request()`.
#'
#' @section Fields:
#' All fields are private:
#' - `.exchange_base_url`: Character; Exchange API base URL (the Advanced Trade
#'   base, credentials, async flag, and perform function are held by the
#'   [connectcore::RestClient] superclass).
#'
#' @importFrom R6 R6Class
#' @export
CoinbaseBase <- R6::R6Class(
  "CoinbaseBase",
  inherit = connectcore::RestClient,
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
      super$initialize(
        keys = keys,
        base_url = base_url,
        async = async,
        body_format = "json",
        user_agent = "dereckscompany/coinbase"
      )
      private$.exchange_base_url <- exchange_base_url
      return(invisible(self))
    }
  ),
  private = list(
    .exchange_base_url = NULL,

    # ---- Coinbase-specific seams (override connectcore::RestClient) ----

    # Authenticate a request with a Coinbase JWT. ctx (connectcore's timestamp
    # source) is unused; the JWT stamps its own nbf/exp from the local clock.
    .sign = function(req, keys, ctx) {
      return(coinbase_jwt_sign(req, keys))
    },

    # Read the Coinbase error envelope and tolerate empty success bodies.
    .parse_envelope = function(resp) {
      return(parse_coinbase_response(resp))
    },

    # Execute a Coinbase API request. Extends connectcore's funnel with a
    # per-request `base_url`: Coinbase splits across two hosts, so a subclass
    # passes the Exchange host for public market-data endpoints and omits it
    # (defaulting to the Advanced Trade host held by the superclass) otherwise.
    #
    # `auth = TRUE` signs the request with the instance's credentials.
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
      return(connectcore::build_request(
        base_url = effective_base,
        endpoint = endpoint,
        method = method,
        query = query,
        body = body,
        keys = if (auth) private$.keys else NULL,
        sign = private$.sign,
        parse_envelope = private$.parse_envelope,
        body_format = private$.body_format,
        .perform = private$.perform,
        .parser = .parser,
        is_async = private$.is_async,
        timeout = timeout,
        user_agent = private$.user_agent,
        max_tries = private$.max_tries,
        throttle_rate = private$.throttle_rate,
        ctx = list(get_timestamp_ms = private$.get_timestamp_ms)
      ))
    }
  )
)
