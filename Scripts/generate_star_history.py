#!/usr/bin/env python3
"""Generate a self-hosted, sketch-style GitHub star history chart."""

from __future__ import annotations

import json
import math
import os
import random
import urllib.error
import urllib.request
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path


REPOSITORY = os.environ.get("GITHUB_REPOSITORY", "walledagoat/SpotifySpatialAudio")
OUTPUT = Path(os.environ.get("STAR_HISTORY_OUTPUT", "Assets/star-history.svg"))
TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
WIDTH = 800
HEIGHT = 500
MARGIN_LEFT = 82
MARGIN_RIGHT = 42
MARGIN_TOP = 92
MARGIN_BOTTOM = 72
PLOT_WIDTH = WIDTH - MARGIN_LEFT - MARGIN_RIGHT
PLOT_HEIGHT = HEIGHT - MARGIN_TOP - MARGIN_BOTTOM


def github_json(path: str) -> tuple[object, dict[str, str]]:
    headers = {
        "Accept": "application/vnd.github.star+json",
        "User-Agent": "SpotifySpatialAudio-star-history",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"

    request = urllib.request.Request(f"https://api.github.com{path}", headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response), dict(response.headers.items())
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GitHub API request failed ({error.code}): {detail}") from error


def fetch_history() -> tuple[date, list[date]]:
    repository, _ = github_json(f"/repos/{REPOSITORY}")
    assert isinstance(repository, dict)
    created = datetime.fromisoformat(str(repository["created_at"]).replace("Z", "+00:00")).date()

    starred_dates: list[date] = []
    page = 1
    while True:
        payload, _ = github_json(f"/repos/{REPOSITORY}/stargazers?per_page=100&page={page}")
        assert isinstance(payload, list)
        for star in payload:
            if isinstance(star, dict) and star.get("starred_at"):
                starred_dates.append(
                    datetime.fromisoformat(str(star["starred_at"]).replace("Z", "+00:00")).date()
                )
        if len(payload) < 100:
            break
        page += 1

    return created, sorted(starred_dates)


def nice_ceiling(value: int) -> int:
    if value <= 5:
        return 5
    magnitude = 10 ** math.floor(math.log10(value))
    normalized = value / magnitude
    step = 2 if normalized <= 2 else 5 if normalized <= 5 else 10
    return step * magnitude


def sketch_path(points: list[tuple[float, float]], seed: int, jitter: float = 0.9) -> str:
    rng = random.Random(seed)
    commands: list[str] = []
    for index, (x, y) in enumerate(points):
        noisy_x = x + rng.uniform(-jitter, jitter)
        noisy_y = y + rng.uniform(-jitter, jitter)
        commands.append(f"{'M' if index == 0 else 'L'} {noisy_x:.1f} {noisy_y:.1f}")
    return " ".join(commands)


def escape_xml(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def generate_svg(created: date, stars: list[date]) -> str:
    counts = Counter(stars)
    end = max(stars[-1] if stars else created, created + timedelta(days=1))
    span = max((end - created).days, 1)

    timeline: list[tuple[date, int]] = [(created, 0)]
    running = 0
    for day in sorted(counts):
        running += counts[day]
        timeline.append((day, running))
    if timeline[-1][0] != end:
        timeline.append((end, running))

    y_max = nice_ceiling(max(running, 1))

    def x_for(day: date) -> float:
        return MARGIN_LEFT + ((day - created).days / span) * PLOT_WIDTH

    def y_for(count: int) -> float:
        return MARGIN_TOP + PLOT_HEIGHT - (count / y_max) * PLOT_HEIGHT

    points = [(x_for(day), y_for(count)) for day, count in timeline]
    axis_x = [(MARGIN_LEFT, MARGIN_TOP + PLOT_HEIGHT), (WIDTH - MARGIN_RIGHT, MARGIN_TOP + PLOT_HEIGHT)]
    axis_y = [(MARGIN_LEFT, MARGIN_TOP), (MARGIN_LEFT, MARGIN_TOP + PLOT_HEIGHT)]

    x_dates = (
        [created, end]
        if span < 14
        else [created, created + timedelta(days=span // 2), end]
    )
    y_ticks = sorted({round(y_max * index / 5) for index in range(6)})
    font = "'Comic Sans MS','Bradley Hand','Chalkboard SE',cursive"

    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-labelledby="title description">',
        '<title id="title">SpotifySpatialAudio GitHub star history</title>',
        f'<desc id="description">A timeline showing {running} GitHub stars for {escape_xml(REPOSITORY)}.</desc>',
        '<rect width="800" height="500" rx="18" fill="#fffdf8"/>',
        f'<text x="400" y="42" text-anchor="middle" font-family="{font}" font-size="30" font-weight="700" fill="#16181d">Star History</text>',
        f'<text x="400" y="69" text-anchor="middle" font-family="{font}" font-size="15" fill="#626873">{escape_xml(REPOSITORY)}</text>',
    ]

    for tick in y_ticks:
        y = y_for(tick)
        elements.append(
            f'<path d="{sketch_path([(MARGIN_LEFT, y), (WIDTH - MARGIN_RIGHT, y)], 1000 + tick, 0.45)}" '
            'fill="none" stroke="#d8dce5" stroke-width="1" stroke-dasharray="5 7"/>'
        )
        elements.append(
            f'<text x="66" y="{y + 5:.1f}" text-anchor="end" font-family="{font}" font-size="13" fill="#6b7280">{tick}</text>'
        )

    elements.extend(
        [
            f'<path d="{sketch_path(axis_x, 10)}" fill="none" stroke="#20242c" stroke-width="2.2" stroke-linecap="round"/>',
            f'<path d="{sketch_path(axis_y, 11)}" fill="none" stroke="#20242c" stroke-width="2.2" stroke-linecap="round"/>',
        ]
    )

    for index, day in enumerate(x_dates):
        x = x_for(day)
        anchor = "start" if index == 0 else "end" if index == len(x_dates) - 1 else "middle"
        elements.append(
            f'<text x="{x:.1f}" y="{HEIGHT - 39}" text-anchor="{anchor}" font-family="{font}" font-size="13" fill="#6b7280">{day.strftime("%b %d, %Y")}</text>'
        )

    line = sketch_path(points, 42, 1.2)
    shadow = sketch_path(points, 43, 1.8)
    elements.extend(
        [
            f'<path d="{shadow}" fill="none" stroke="#8fb3ff" stroke-width="5" opacity="0.35" stroke-linecap="round" stroke-linejoin="round"/>',
            f'<path d="{line}" fill="none" stroke="#2563eb" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
        ]
    )

    if stars:
        last_x, last_y = points[-1]
        elements.extend(
            [
                f'<circle cx="{last_x:.1f}" cy="{last_y:.1f}" r="7" fill="#fffdf8" stroke="#2563eb" stroke-width="3"/>',
                f'<text x="{last_x - 8:.1f}" y="{max(last_y - 18, 96):.1f}" text-anchor="end" font-family="{font}" font-size="18" font-weight="700" fill="#16181d">{running} star{"" if running == 1 else "s"}</text>',
            ]
        )
    else:
        elements.append(
            f'<text x="400" y="250" text-anchor="middle" font-family="{font}" font-size="22" fill="#626873">Waiting for the first star...</text>'
        )

    elements.extend(
        [
            f'<text x="758" y="475" text-anchor="end" font-family="{font}" font-size="12" fill="#9aa0aa">Updated automatically by GitHub Actions</text>',
            "</svg>",
        ]
    )
    return "\n".join(elements) + "\n"


def main() -> None:
    created, stars = fetch_history()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generate_svg(created, stars), encoding="utf-8")
    print(f"Generated {OUTPUT} with {len(stars)} stars at {datetime.now(timezone.utc).isoformat()}.")


if __name__ == "__main__":
    main()
