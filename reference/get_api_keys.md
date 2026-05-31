# Retrieve Coinbase API Credentials

Fetches Coinbase Advanced Trade (CDP) API credentials from environment
variables or explicit arguments. Credentials are created at
<https://www.coinbase.com/settings/api> and downloaded as a JSON file
containing a `name` and a `privateKey`.

## Usage

``` r
get_api_keys(
  api_key_name = Sys.getenv("COINBASE_API_KEY_NAME"),
  api_private_key = Sys.getenv("COINBASE_API_PRIVATE_KEY")
)
```

## Arguments

- api_key_name:

  Character string; the credential `name`, e.g.
  `"organizations/<org-uuid>/apiKeys/<key-uuid>"`. Defaults to
  `Sys.getenv("COINBASE_API_KEY_NAME")`.

- api_private_key:

  Character string; the credential `privateKey`. Defaults to
  `Sys.getenv("COINBASE_API_PRIVATE_KEY")`.

## Value

Named list with `api_key_name` and `api_private_key` (newlines
unescaped).

## Details

Required environment variables: `COINBASE_API_KEY_NAME`,
`COINBASE_API_PRIVATE_KEY`.

### Private key formatting

The downloaded `privateKey` is a multi-line value. To store it on a
single line in `.Renviron`, escape the newlines as the two characters
`\\n`; this function unescapes them back to real newlines before use.
Both EC (`-----BEGIN EC PRIVATE KEY-----`, signed with ES256) and
base64-encoded Ed25519 keys (signed with EdDSA) are supported by the
signer.

## Examples

``` r
if (FALSE) { # \dontrun{
keys <- get_api_keys()
} # }
```
