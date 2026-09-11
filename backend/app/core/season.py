import datetime

SEASONS = ("봄", "여름", "가을", "겨울")

_MONTH_TO_SEASON = {
    3: "봄", 4: "봄", 5: "봄",
    6: "여름", 7: "여름", 8: "여름",
    9: "가을", 10: "가을", 11: "가을",
    12: "겨울", 1: "겨울", 2: "겨울",
}


def current_season() -> str:
    return _MONTH_TO_SEASON[datetime.date.today().month]
