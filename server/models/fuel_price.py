from datetime import date

from pydantic import BaseModel

from models.fuel_type import FuelType


class FuelPriceAttribution(BaseModel):
    text: str
    url: str
    license: str = ""
    note: str = ""


class FuelPricePoint(BaseModel):
    date: date
    price: float


class FuelPriceSeries(BaseModel):
    fuel_type: str
    points: list[FuelPricePoint]

    @property
    def fuel(self) -> FuelType | None:
        try:
            return FuelType(self.fuel_type)
        except ValueError:
            return None

    def price_on(self, day: date) -> float | None:
        for point in self.points:
            if point.date == day:
                return point.price
        return None


class CountryFuelPriceHistory(BaseModel):
    cc: str
    series: list[FuelPriceSeries]
    missing_weeks: list[date]
    isolated: dict[str, list[date]]
    attribution: FuelPriceAttribution

    def series_for(self, fuel_type: str | FuelType) -> FuelPriceSeries | None:
        for series in self.series:
            if isinstance(fuel_type, FuelType):
                if series.fuel == fuel_type:
                    return series
            elif series.fuel_type == fuel_type:
                return series
        return None

    def latest(self, fuel_type: str | FuelType) -> FuelPricePoint | None:
        series = self.series_for(fuel_type)
        if series is None or not series.points:
            return None
        return max(series.points, key=lambda point: point.date)
