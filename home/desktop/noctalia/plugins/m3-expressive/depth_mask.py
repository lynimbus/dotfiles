#!/usr/bin/env python3
"""Generate widget-aware Depth Anything V2 wallpaper foreground masks for Noctalia.

Interactive and text widgets are always kept above the foreground mask so wallpapers
never bury controls or lyrics. Clock widgets follow an iOS-style occlusion guard:
subtle edge overlap is preserved, while heavy or center occlusion clears the mask
over the clock so time stays crisp and readable. Decorative widgets (audio visualizer)
always receive the full foreground depth effect.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import time
import urllib.request

MODEL_REVISION = "4472b7362082ad9968fee890ca0f1e5aca36b93d"
MODEL_URL = (
    "https://huggingface.co/onnx-community/depth-anything-v2-small/resolve/"
    f"{MODEL_REVISION}/onnx/model.onnx?download=true"
)
MODEL_SHA256 = "afb6a5c28f3b6bf1618c6e43f02073ef9dfdc70e937502d51603e57b0a1df10c"
MODEL_SIZE = 99_060_839
INPUT_SIZE = 518
MODEL_PATCH_SIZE = 14
DEPTH_PIPELINE_VERSION = 2
MASK_PIPELINE_VERSION = 4
REFINEMENT_MAX_DIMENSION = 1920
GUIDED_FILTER_RADIUS = 8
GUIDED_FILTER_EPSILON = 0.001


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_model(path: Path) -> bool:
    return path.is_file() and path.stat().st_size == MODEL_SIZE and sha256_file(path) == MODEL_SHA256


def resolve_model_path(data_dir: Path) -> Path:
    local = data_dir / "models" / "depth-anything-v2-small" / "model.onnx"
    if verify_model(local):
        return local
    shared = (
        Path.home()
        / ".local"
        / "state"
        / "noctalia"
        / "plugins"
        / "data"
        / "noctalia"
        / "wallpaper_depth"
        / "models"
        / "depth-anything-v2-small"
        / "model.onnx"
    )
    if verify_model(shared):
        return shared
    download_model(local)
    return local


def download_model(destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(".onnx.part")
    temporary.unlink(missing_ok=True)
    request = urllib.request.Request(MODEL_URL, headers={"User-Agent": "Noctalia-M3-Depth/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response, temporary.open("wb") as stream:
            while chunk := response.read(1024 * 1024):
                stream.write(chunk)
        if temporary.stat().st_size != MODEL_SIZE:
            raise RuntimeError(
                f"model size mismatch: expected {MODEL_SIZE}, got {temporary.stat().st_size}"
            )
        checksum = sha256_file(temporary)
        if checksum != MODEL_SHA256:
            raise RuntimeError(f"model checksum mismatch: expected {MODEL_SHA256}, got {checksum}")
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def inference_size(source_width: int, source_height: int) -> tuple[int, int]:
    scale = max(INPUT_SIZE / source_width, INPUT_SIZE / source_height)
    width = max(INPUT_SIZE, round(source_width * scale / MODEL_PATCH_SIZE) * MODEL_PATCH_SIZE)
    height = max(INPUT_SIZE, round(source_height * scale / MODEL_PATCH_SIZE) * MODEL_PATCH_SIZE)
    return width, height


def smoothstep(values, low: float, high: float):
    import numpy as np

    if high <= low:
        return (values >= high).astype(np.float32)
    scaled = np.clip((values - low) / (high - low), 0.0, 1.0)
    return scaled * scaled * (3.0 - 2.0 * scaled)


def box_mean(values, radius: int):
    import numpy as np

    padded = np.pad(values, ((radius, radius), (radius, radius)), mode="edge")
    integral = np.pad(padded, ((1, 0), (1, 0)), mode="constant")
    integral = np.cumsum(integral, axis=0, dtype=np.float64)
    integral = np.cumsum(integral, axis=1, dtype=np.float64)
    diameter = radius * 2 + 1
    total = (
        integral[diameter:, diameter:]
        - integral[:-diameter, diameter:]
        - integral[diameter:, :-diameter]
        + integral[:-diameter, :-diameter]
    )
    total *= 1.0 / (diameter * diameter)
    return total.astype(np.float32)


def refine_depth(source_rgb, depth):
    import numpy as np
    from PIL import Image

    source_width, source_height = source_rgb.size
    scale = min(1.0, REFINEMENT_MAX_DIMENSION / max(source_width, source_height))
    refinement_size = (
        max(1, round(source_width * scale)),
        max(1, round(source_height * scale)),
    )
    guide_image = source_rgb.convert("L")
    if guide_image.size != refinement_size:
        guide_image = guide_image.resize(refinement_size, Image.Resampling.LANCZOS)
    guide = np.asarray(guide_image, dtype=np.float32) / np.float32(255.0)
    coarse = np.asarray(
        Image.fromarray(depth).resize(refinement_size, Image.Resampling.BICUBIC),
        dtype=np.float32,
    )

    mean_guide = box_mean(guide, GUIDED_FILTER_RADIUS)
    mean_depth = box_mean(coarse, GUIDED_FILTER_RADIUS)
    correlation_guide = box_mean(guide * guide, GUIDED_FILTER_RADIUS)
    correlation_cross = box_mean(guide * coarse, GUIDED_FILTER_RADIUS)
    variance_guide = correlation_guide - mean_guide * mean_guide
    covariance = correlation_cross - mean_guide * mean_depth
    coefficient_a = covariance / (variance_guide + np.float32(GUIDED_FILTER_EPSILON))
    coefficient_b = mean_depth - coefficient_a * mean_guide
    refined = np.clip(
        box_mean(coefficient_a, GUIDED_FILTER_RADIUS) * guide
        + box_mean(coefficient_b, GUIDED_FILTER_RADIUS),
        0.0,
        1.0,
    ).astype(np.float32)

    if refinement_size != (source_width, source_height):
        refined = np.asarray(
            Image.fromarray(refined).resize((source_width, source_height), Image.Resampling.BICUBIC),
            dtype=np.float32,
        )
    return refined


def screen_rect_to_source(
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    out_w: float,
    out_h: float,
    src_w: int,
    src_h: int,
    fill_mode: str,
) -> tuple[int, int, int, int] | None:
    if out_w <= 0 or out_h <= 0:
        return None
    mode = fill_mode.lower()
    if mode == "fit":
        scale = min(out_w / src_w, out_h / src_h)
        dx = (out_w - src_w * scale) * 0.5
        dy = (out_h - src_h * scale) * 0.5
        sx0, sy0 = (x0 - dx) / scale, (y0 - dy) / scale
        sx1, sy1 = (x1 - dx) / scale, (y1 - dy) / scale
    elif mode == "stretch":
        sx0, sy0 = x0 * src_w / out_w, y0 * src_h / out_h
        sx1, sy1 = x1 * src_w / out_w, y1 * src_h / out_h
    elif mode == "center":
        ox = (src_w - out_w) * 0.5
        oy = (src_h - out_h) * 0.5
        sx0, sy0 = ox + x0, oy + y0
        sx1, sy1 = ox + x1, oy + y1
    else:
        # Default "crop" (aspect-preserving cover, centered).
        scale = max(out_w / src_w, out_h / src_h)
        ox = (src_w - out_w / scale) * 0.5
        oy = (src_h - out_h / scale) * 0.5
        sx0, sy0 = ox + x0 / scale, oy + y0 / scale
        sx1, sy1 = ox + x1 / scale, oy + y1 / scale

    ix0 = max(0, min(src_w, int(sx0)))
    iy0 = max(0, min(src_h, int(sy0)))
    ix1 = max(0, min(src_w, int(round(sx1))))
    iy1 = max(0, min(src_h, int(round(sy1))))
    if ix1 <= ix0 or iy1 <= iy0:
        return None
    return ix0, iy0, ix1, iy1


def apply_widget_guards(
    alpha,
    widgets: list[dict[str, object]],
    out_w: float,
    out_h: float,
    fill_mode: str,
    max_clock_occlusion: float,
) -> list[str]:
    import numpy as np

    src_h, src_w = alpha.shape
    cleared: list[str] = []
    max_core_occlusion = min(0.12, max_clock_occlusion * 0.5)

    for widget in widgets:
        role = str(widget.get("role", "protect"))
        if role == "depth":
            continue

        cx = float(widget.get("cx", 0.0))
        cy = float(widget.get("cy", 0.0))
        width = float(widget.get("width", 0.0))
        height = float(widget.get("height", 0.0))
        pad_x = float(widget.get("pad_x", 16.0))
        pad_y = float(widget.get("pad_y", 16.0))
        if width <= 0 or height <= 0:
            continue

        x0, y0 = cx - width * 0.5, cy - height * 0.5
        x1, y1 = cx + width * 0.5, cy + height * 0.5

        should_clear = role == "protect"
        if role == "clock":
            rect = screen_rect_to_source(x0, y0, x1, y1, out_w, out_h, src_w, src_h, fill_mode)
            if rect is not None:
                ix0, iy0, ix1, iy1 = rect
                patch = alpha[iy0:iy1, ix0:ix1]
                total_cov = float(np.mean(patch > 0.25))
                # Inner 60% covers clock hands and cardinal numerals.
                mx = int((ix1 - ix0) * 0.2)
                my = int((iy1 - iy0) * 0.2)
                core = alpha[iy0 + my : max(iy0 + my + 1, iy1 - my), ix0 + mx : max(ix0 + mx + 1, ix1 - mx)]
                core_cov = float(np.mean(core > 0.25))
                should_clear = total_cov > max_clock_occlusion or core_cov > max_core_occlusion

        if should_clear:
            padded = screen_rect_to_source(
                x0 - pad_x,
                y0 - pad_y,
                x1 + pad_x,
                y1 + pad_y,
                out_w,
                out_h,
                src_w,
                src_h,
                fill_mode,
            )
            if padded is not None:
                px0, py0, px1, py1 = padded
                alpha[py0:py1, px0:px1] = 0.0
                cleared.append(str(widget.get("id", role)))

    return cleared


def prune(directory: Path, maximum: int) -> None:
    if not directory.is_dir():
        return
    files = sorted(
        (path for path in directory.iterdir() if path.is_file()),
        key=lambda path: path.stat().st_mtime_ns,
        reverse=True,
    )
    for path in files[maximum:]:
        path.unlink(missing_ok=True)


def emit(value: dict[str, object]) -> None:
    print(json.dumps(value, separators=(",", ":"), sort_keys=True), flush=True)


def generate(
    data_dir: Path,
    wallpaper: Path,
    threshold: float,
    feather: float,
    max_clock_occlusion: float,
    out_w: float,
    out_h: float,
    fill_mode: str,
    widgets_json: str,
) -> None:
    import numpy as np
    import onnxruntime as ort
    from PIL import Image

    if not wallpaper.is_file():
        raise RuntimeError("wallpaper is missing or unreadable")

    threshold = min(1.0, max(0.0, threshold))
    feather = min(0.5, max(0.0, feather))
    max_clock_occlusion = min(1.0, max(0.0, max_clock_occlusion))
    widgets = json.loads(widgets_json) if widgets_json else []
    if not isinstance(widgets, list):
        widgets = []

    started = time.monotonic()
    wallpaper_hash = sha256_file(wallpaper)
    depth_key = f"{wallpaper_hash}-{MODEL_SHA256[:16]}-d{DEPTH_PIPELINE_VERSION}-i{INPUT_SIZE}"

    layout_sig = hashlib.sha256(
        json.dumps(
            {
                "fill_mode": fill_mode,
                "max_clock_occlusion": round(max_clock_occlusion, 4),
                "out_h": round(out_h, 2),
                "out_w": round(out_w, 2),
                "widgets": widgets,
            },
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()[:12]

    depth_dir = data_dir / "cache" / "depth"
    mask_dir = data_dir / "cache" / "masks"
    depth_dir.mkdir(parents=True, exist_ok=True)
    mask_dir.mkdir(parents=True, exist_ok=True)
    depth_path = depth_dir / f"{depth_key}.npy"
    shared_depth_path = (
        Path.home()
        / ".local"
        / "state"
        / "noctalia"
        / "plugins"
        / "data"
        / "noctalia"
        / "wallpaper_depth"
        / "cache"
        / "depth"
        / f"{depth_key}.npy"
    )
    mask_key = (
        f"{depth_key}-v{MASK_PIPELINE_VERSION}-t{threshold:.4f}-f{feather:.4f}-w{layout_sig}"
    )
    mask_path = mask_dir / f"{mask_key}.png"
    lock_path = data_dir / "cache" / "generate.lock"

    cleared_widgets: list[str] = []
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with Image.open(wallpaper) as source:
            source_rgb = source.convert("RGB")
            source_width, source_height = source_rgb.size
            if source_width <= 0 or source_height <= 0:
                raise RuntimeError("wallpaper has invalid dimensions")

            if mask_path.is_file():
                with Image.open(mask_path) as cached_mask:
                    if cached_mask.size == (source_width, source_height):
                        emit(
                            {
                                "cacheHit": True,
                                "elapsedMs": round((time.monotonic() - started) * 1000),
                                "height": source_height,
                                "maskPath": str(mask_path),
                                "wallpaperPath": str(wallpaper),
                                "width": source_width,
                            }
                        )
                        return
                mask_path.unlink(missing_ok=True)

            model_width, model_height = inference_size(source_width, source_height)
            depth = None
            depth_hit = False
            for candidate in (depth_path, shared_depth_path):
                if candidate.is_file():
                    loaded = np.load(candidate, allow_pickle=False)
                    if loaded.shape == (model_height, model_width):
                        depth = loaded
                        depth_hit = True
                        break
                    if candidate == depth_path:
                        depth_path.unlink(missing_ok=True)

            if depth is None:
                model_file = resolve_model_path(data_dir)
                resized = source_rgb.resize((model_width, model_height), Image.Resampling.BICUBIC)
                pixels = np.asarray(resized, dtype=np.float32) / np.float32(255.0)
                pixels = (pixels - np.array([0.485, 0.456, 0.406], dtype=np.float32)) / np.array(
                    [0.229, 0.224, 0.225], dtype=np.float32
                )
                tensor = np.transpose(pixels, (2, 0, 1))[None, ...]
                options = ort.SessionOptions()
                options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
                session = ort.InferenceSession(
                    str(model_file), sess_options=options, providers=["CPUExecutionProvider"]
                )
                input_name = session.get_inputs()[0].name
                prediction = session.run(None, {input_name: tensor})[0]
                depth = np.asarray(prediction, dtype=np.float32).squeeze()
                if depth.shape != (model_height, model_width):
                    raise RuntimeError(
                        f"unexpected model output shape: {depth.shape}; expected {(model_height, model_width)}"
                    )
                minimum = float(np.min(depth))
                maximum = float(np.max(depth))
                if not np.isfinite(minimum) or not np.isfinite(maximum) or maximum <= minimum:
                    raise RuntimeError("model returned an invalid depth map")
                depth = (depth - minimum) / (maximum - minimum)
                with tempfile.NamedTemporaryFile("wb", dir=depth_dir, delete=False) as stream:
                    np.save(stream, depth, allow_pickle=False)
                    temporary_depth = Path(stream.name)
                os.replace(temporary_depth, depth_path)

            full_size_depth = refine_depth(source_rgb, depth)
            half_feather = feather * 0.5
            alpha = smoothstep(full_size_depth, threshold - half_feather, threshold + half_feather)
            cleared_widgets = apply_widget_guards(
                alpha,
                widgets,
                out_w,
                out_h,
                fill_mode,
                max_clock_occlusion,
            )
            alpha_image = Image.fromarray(np.rint(alpha * 255.0).astype(np.uint8))
            with tempfile.NamedTemporaryFile("wb", dir=mask_dir, delete=False) as stream:
                alpha_image.save(stream, format="PNG", optimize=True)
                temporary_mask = Path(stream.name)
            os.replace(temporary_mask, mask_path)

        prune(depth_dir, 16)
        prune(mask_dir, 32)

    emit(
        {
            "cacheHit": depth_hit,
            "clearedWidgets": cleared_widgets,
            "elapsedMs": round((time.monotonic() - started) * 1000),
            "height": source_height,
            "maskPath": str(mask_path),
            "wallpaperPath": str(wallpaper),
            "width": source_width,
        }
    )


def clear_cache(data_dir: Path) -> None:
    shutil.rmtree(data_dir / "cache", ignore_errors=True)
    emit({"cleared": True})


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", required=True, type=Path)
    sub = parser.add_subparsers(dest="command", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("--wallpaper", required=True, type=Path)
    gen.add_argument("--threshold", required=True, type=float)
    gen.add_argument("--feather", required=True, type=float)
    gen.add_argument("--max-clock-occlusion", required=True, type=float)
    gen.add_argument("--output-width", required=True, type=float)
    gen.add_argument("--output-height", required=True, type=float)
    gen.add_argument("--fill-mode", default="crop")
    gen.add_argument("--widgets-json", default="[]")
    sub.add_parser("clear-cache")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    data_dir = args.data_dir.expanduser().resolve()
    try:
        if args.command == "generate":
            generate(
                data_dir=data_dir,
                wallpaper=args.wallpaper.expanduser(),
                threshold=args.threshold,
                feather=args.feather,
                max_clock_occlusion=args.max_clock_occlusion,
                out_w=args.output_width,
                out_h=args.output_height,
                fill_mode=args.fill_mode,
                widgets_json=args.widgets_json,
            )
        elif args.command == "clear-cache":
            clear_cache(data_dir)
        return 0
    except Exception as error:
        print(str(error), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    import sys

    raise SystemExit(main())
