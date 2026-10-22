import logging
import os
from datetime import date
from typing import Any

import httpx
from pydantic import ValidationError

from models.fuel_price import (
    CountryFuelPriceHistory,
    FuelPriceAttribution,
    FuelPricePoint,
    FuelPriceSeries,
)

logger = logging.getLogger(__name__)

BASE_URL = os.environ.get("FUEL_PRICES_BASE_URL", "https://www.fuel-prices.eu")
COUNTRY_HISTORY_PATH = "/lang/api/country-history.php"
DEFAULT_TIMEOUT = float(os.environ.get("FUEL_PRICES_TIMEOUT", "10"))
USER_AGENT = os.environ.get("FUEL_PRICES_USER_AGENT", "fuel-tracker/0.1")

_HEADERS = {"User-Agent": USER_AGENT, "Accept": "application/json"}
_RESERVED_KEYS = {"cc", "labels", "count", "missing_weeks", "isolated", "attribution"}


class FuelPriceError(Exception):
    """Raised when the fuel-prices.eu API cannot be used."""


class InvalidCountryCodeError(FuelPriceError):
    """Raised when the country code is not a two letter country code."""


class CountryNotFoundError(FuelPriceError):
    """Raised when the country code is valid but has no price history."""


class FuelPriceServiceError(FuelPriceError):
    """Raised when the upstream response cannot be reached or parsed."""


def fetch_country_history(
    country_code: str,
    *,
    timeout: float = DEFAULT_TIMEOUT,
) -> CountryFuelPriceHistory:
    """Fetch the weekly fuel price history of a country from fuel-prices.eu.

    Args:
        country_code: Two letter country code, for example "NL".
        timeout: Timeout in seconds for the upstream request.

    Returns:
        The parsed price history of the country.

    Raises:
        InvalidCountryCodeError: The country code is not two letters.
        CountryNotFoundError: The country code has no price history.
        FuelPriceServiceError: The upstream service failed or answered garbage.
    """
    code = normalize_country_code(country_code)
    try:
        with httpx.Client(timeout=timeout, headers=_HEADERS) as client:
            response = client.get(country_history_url(), params={"cc": code})
    except httpx.RequestError as exc:
        raise FuelPriceServiceError(f"Could not reach fuel-prices.eu: {exc}") from exc
    return parse_country_history(response)


async def fetch_country_history_async(
    country_code: str,
    *,
    timeout: float = DEFAULT_TIMEOUT,
) -> CountryFuelPriceHistory:
    """Async variant of fetch_country_history.

    Args:
        country_code: Two letter country code, for example "NL".
        timeout: Timeout in seconds for the upstream request.

    Returns:
        The parsed price history of the country.

    Raises:
        InvalidCountryCodeError: The country code is not two letters.
        CountryNotFoundError: The country code has no price history.
        FuelPriceServiceError: The upstream service failed or answered garbage.
    """
    code = normalize_country_code(country_code)
    try:
        async with httpx.AsyncClient(timeout=timeout, headers=_HEADERS) as client:
            response = await client.get(country_history_url(), params={"cc": code})
    except httpx.RequestError as exc:
        raise FuelPriceServiceError(f"Could not reach fuel-prices.eu: {exc}") from exc
    return parse_country_history(response)


def country_history_url() -> str:
    """Return the upstream url of the country history endpoint."""
    return f"{BASE_URL}{COUNTRY_HISTORY_PATH}"


def normalize_country_code(country_code: str) -> str:
    """Uppercase and validate a country code before calling the upstream API.

    Args:
        country_code: Two letter country code, for example "nl".

    Returns:
        The normalized country code.

    Raises:
        InvalidCountryCodeError: The country code is not two letters.
    """
    code = country_code.strip().upper()
    if len(code) != 2 or not code.isalpha():
        raise InvalidCountryCodeError(
            f"Invalid country code '{country_code}'. "
            "Use a two letter country code, for example NL."
        )
    return code


def parse_country_history(response: httpx.Response) -> CountryFuelPriceHistory:
    """Turn an upstream response into a CountryFuelPriceHistory.

    Args:
        response: The response of the country history endpoint.

    Returns:
        The parsed price history.

    Raises:
        InvalidCountryCodeError: The upstream rejected the country code.
        CountryNotFoundError: The upstream has no data for the country code.
        FuelPriceServiceError: The upstream response could not be parsed.
    """
    if response.status_code == 400:
        raise InvalidCountryCodeError(
            _error_message(response) or "Invalid country code"
        )
    if response.status_code == 404:
        raise CountryNotFoundError(
            _error_message(response) or "No price history for country code"
        )
    if response.status_code >= 400:
        raise FuelPriceServiceError(
            f"Fuel prices API returned HTTP {response.status_code}"
        )

    payload = _json_body(response)
    if not isinstance(payload, dict):
        raise FuelPriceServiceError("Fuel prices API returned an unexpected response")

    error = payload.get("error")
    if error:
        raise FuelPriceServiceError(str(error))

    labels = [_parse_date(value) for value in _as_list(payload.get("labels"))]

    series: list[FuelPriceSeries] = []
    for name, values in payload.items():
        if name in _RESERVED_KEYS:
            continue
        if not isinstance(values, list):
            continue
        if len(values) != len(labels):
            raise FuelPriceServiceError(
                f"Series '{name}' has {len(values)} values "
                f"but {len(labels)} dates"
            )
        points = [
            FuelPricePoint(date=label, price=_parse_price(value))
            for label, value in zip(labels, values)
            if value is not None
        ]
        series.append(FuelPriceSeries(fuel_type=name, points=points))

    missing_weeks = [
        _parse_date(value) for value in _as_list(payload.get("missing_weeks"))
    ]

    isolated: dict[str, list[date]] = {}
    raw_isolated = payload.get("isolated")
    if isinstance(raw_isolated, dict):
        for name, values in raw_isolated.items():
            isolated[str(name)] = [_parse_date(value) for value in _as_list(values)]

    return CountryFuelPriceHistory(
        cc=str(payload.get("cc", "")),
        series=series,
        missing_weeks=missing_weeks,
        isolated=isolated,
        attribution=_parse_attribution(payload.get("attribution")),
    )


def _json_body(response: httpx.Response) -> Any:
    try:
        return response.json()
    except ValueError as exc:
        raise FuelPriceServiceError(
            "Fuel prices API returned a malformed response"
        ) from exc


def _error_message(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        return ""
    if isinstance(payload, dict):
        return str(payload.get("error", ""))
    return ""


def _as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _parse_date(value: Any) -> date:
    try:
        return date.fromisoformat(str(value))
    except ValueError as exc:
        raise FuelPriceServiceError(
            f"Fuel prices API returned an invalid date '{value}'"
        ) from exc


def _parse_price(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise FuelPriceServiceError(
            f"Fuel prices API returned an invalid price '{value}'"
        ) from exc


def _parse_attribution(value: Any) -> FuelPriceAttribution:
    if not isinstance(value, dict):
        raise FuelPriceServiceError("Fuel prices API returned no attribution")
    try:
        return FuelPriceAttribution.model_validate(value)
    except ValidationError as exc:
        raise FuelPriceServiceError(
            "Fuel prices API returned an invalid attribution"
        ) from exc
