#!/usr/bin/env python3
"""Asset Generator CLI - creates images (ModelScope Qwen) and GLBs (Tripo3D).

Subcommands:
  image   Generate a PNG from a prompt
  video   Generate MP4 video from prompt + reference image (5¢/sec)
  glb     Convert a PNG to a GLB 3D model via Tripo3D (30-60¢)

Output: JSON to stdout. Progress to stderr.
"""

import argparse
import base64
import io
import json
import sys
import time
from pathlib import Path

import requests
from PIL import Image

from tripo3d import MODEL_V3, image_to_glb

TOOLS_DIR = Path(__file__).parent
BUDGET_FILE = Path("assets/budget.json")

MODELSCOPE_API_KEY = "ms-28230386-a9ef-41bd-8982-a2d474026996"
MODELSCOPE_BASE_URL = "https://api-inference.modelscope.cn/v1"
MODELSCOPE_MODEL = "Qwen/Qwen-Image"
POLL_INTERVAL = 3  # seconds between task status polls
POLL_TIMEOUT = 120  # max seconds to wait for task completion

VIDEO_COST_PER_SEC = 5  # cents (video disabled for ModelScope)


def _load_budget():
    if not BUDGET_FILE.exists():
        return None
    return json.loads(BUDGET_FILE.read_text())


def _spent_total(budget):
    return sum(v for entry in budget.get("log", []) for v in entry.values())


def check_budget(cost_cents: int):
    """Check remaining budget. Exit with error JSON if insufficient."""
    budget = _load_budget()
    if budget is None:
        return
    spent = _spent_total(budget)
    remaining = budget.get("budget_cents", 0) - spent
    if cost_cents > remaining:
        result_json(False, error=f"Budget exceeded: need {cost_cents}¢ but only {remaining}¢ remaining ({spent}¢ of {budget['budget_cents']}¢ spent)")
        sys.exit(1)


def record_spend(cost_cents: int, service: str):
    """Append a generation record to the budget log."""
    budget = _load_budget()
    if budget is None:
        return
    budget.setdefault("log", []).append({service: cost_cents})
    BUDGET_FILE.write_text(json.dumps(budget, indent=2) + "\n")

QUALITY_PRESETS = {
    "lowpoly": {
        "face_limit": 5000,
        "smart_low_poly": True,
        "texture_quality": "standard",
        "geometry_quality": "standard",
        "cost_cents": 40,
    },
    "medium": {
        "face_limit": 20000,
        "smart_low_poly": False,
        "texture_quality": "standard",
        "geometry_quality": "standard",
        "cost_cents": 30,
    },
    "high": {
        "face_limit": None,
        "smart_low_poly": False,
        "texture_quality": "detailed",
        "geometry_quality": "standard",
        "cost_cents": 40,
    },
    "ultra": {
        "face_limit": None,
        "smart_low_poly": False,
        "texture_quality": "detailed",
        "geometry_quality": "detailed",
        "cost_cents": 60,
    },
}


def result_json(ok: bool, path: str | None = None, cost_cents: int = 0, error: str | None = None):
    d = {"ok": ok, "cost_cents": cost_cents}
    if path:
        d["path"] = path
    if error:
        d["error"] = error
    print(json.dumps(d))


IMAGE_MODELS = {"standard": "Qwen/Qwen-Image", "pro": "Qwen/Qwen-Image"}
IMAGE_COSTS = {"standard": 2, "pro": 7}
IMAGE_SIZES = ["1024x1024", "1024x576", "576x1024", "1024x2048", "2048x1024"]
IMAGE_ASPECT_RATIOS = [
    "1:1", "16:9", "9:16", "3:4", "4:3", "2:3", "3:2",
    "2:1", "1:2", "19.5:9", "9:19.5", "20:9", "9:20", "auto",
]

# Map aspect ratio to size for ModelScope API
ASPECT_TO_SIZE = {
    "1:1": "1024x1024",
    "16:9": "1024x576",
    "9:16": "576x1024",
    "3:4": "768x1024",
    "4:3": "1024x768",
    "3:2": "1024x683",
    "2:3": "683x1024",
    "2:1": "1024x512",
    "1:2": "512x1024",
    "19.5:9": "1088x512",
    "9:19.5": "512x1088",
    "20:9": "1138x512",
    "9:20": "512x1138",
    "auto": "1024x1024",
}


def _image_data_uri(image_path: Path) -> str:
    """Load image and return as base64 data URI."""
    b64 = base64.b64encode(image_path.read_bytes()).decode()
    return f"data:image/png;base64,{b64}"


def _headers():
    return {
        "Authorization": f"Bearer {MODELSCOPE_API_KEY}",
        "Content-Type": "application/json",
        "X-ModelScope-Async-Mode": "true",
    }


def _poll_task(task_id: str) -> dict:
    """Poll task status until SUCCEED or FAILED."""
    url = f"{MODELSCOPE_BASE_URL}/tasks/{task_id}"
    start = time.time()
    while time.time() - start < POLL_TIMEOUT:
        resp = requests.get(
            url,
            headers={**_headers(), "X-ModelScope-Task-Type": "image_generation"},
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        status = data.get("status", "")
        if status == "SUCCEED":
            return data
        elif status == "FAILED":
            raise RuntimeError(f"Task failed: {data.get('error', 'unknown')}")
        print(f"  Task {task_id} status: {status}, waiting...", file=sys.stderr)
        time.sleep(POLL_INTERVAL)
    raise RuntimeError(f"Task polling timed out after {POLL_TIMEOUT}s")


def cmd_image(args):
    tier = args.model
    cost = IMAGE_COSTS[tier]
    check_budget(cost)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    label = f"{tier} {args.size} {args.aspect_ratio}"
    if args.image:
        label += " (image-to-image)"
    print(f"Generating image via ModelScope ({label})...", file=sys.stderr)

    # Map size or use explicit size
    if args.size not in IMAGE_SIZES:
        size = ASPECT_TO_SIZE.get(args.aspect_ratio, "1024x1024")
    else:
        size = args.size

    # Note: ModelScope Qwen-Image doesn't support image-to-image reference
    if args.image:
        print("  Note: image-to-image not supported by ModelScope Qwen-Image, generating from prompt only", file=sys.stderr)

    payload = {
        "model": MODELSCOPE_MODEL,
        "prompt": args.prompt,
        "size": size,
        "n": 1,
    }

    try:
        # Step 1: Submit generation task
        submit_url = f"{MODELSCOPE_BASE_URL}/images/generations"
        resp = requests.post(submit_url, headers=_headers(), json=payload, timeout=30)
        resp.raise_for_status()
        result = resp.json()

        # Extract task_id - may be direct output or async task
        task_id = result.get("task_id")
        if not task_id:
            # Synchronous mode - image URL directly returned
            image_url = result.get("data", [{}])[0].get("url") or result.get("output", {}).get("image_url")
            if not image_url:
                raise RuntimeError(f"No task_id and no image_url in response: {result}")
            print(f"  Direct response (sync mode): {image_url}", file=sys.stderr)
        else:
            # Async mode - poll for result
            print(f"  Task submitted: {task_id}, polling...", file=sys.stderr)
            result = _poll_task(task_id)
            image_url = (
                result.get("output", {}).get("image_url")
                or result.get("data", [{}])[0].get("url")
            )
            if not image_url:
                raise RuntimeError(f"No image_url in poll result: {result}")

        # Step 3: Download image
        print(f"  Downloading from: {image_url}", file=sys.stderr)
        dl = requests.get(image_url, timeout=120)
        dl.raise_for_status()

        # Determine format and save
        content_type = dl.headers.get("Content-Type", "")
        if "jpeg" in content_type or "jpg" in content_type:
            img = Image.open(io.BytesIO(dl.content))
            img.save(output, format="PNG")
        else:
            output.write_bytes(dl.content)

    except requests.HTTPError as e:
        result_json(False, error=f"HTTP {e.response.status_code}: {e.response.text}")
        sys.exit(1)
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    print(f"Saved: {output}", file=sys.stderr)
    record_spend(cost, "modelscope")
    result_json(True, path=str(output), cost_cents=cost)


def cmd_video(args):
    # ModelScope Qwen-Image does not support video generation.
    # Stub with error to avoid confusing xai_sdk failures.
    result_json(False, error="Video generation is not supported with ModelScope API. Use xAI Grok for video.")
    sys.exit(1)


def cmd_glb(args):
    image_path = Path(args.image)
    if not image_path.exists():
        result_json(False, error=f"Image not found: {image_path}")
        sys.exit(1)

    preset = QUALITY_PRESETS.get(args.quality, QUALITY_PRESETS["medium"])
    check_budget(preset["cost_cents"])

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    print(f"Converting to GLB (quality={args.quality})...", file=sys.stderr)

    try:
        image_to_glb(
            image_path,
            output,
            model_version=MODEL_V3,
            face_limit=preset["face_limit"],
            smart_low_poly=preset["smart_low_poly"],
            texture_quality=preset["texture_quality"],
            geometry_quality=preset["geometry_quality"],
        )
    except Exception as e:
        result_json(False, error=str(e))
        sys.exit(1)

    print(f"Saved: {output}", file=sys.stderr)
    record_spend(preset["cost_cents"], "tripo3d")
    result_json(True, path=str(output), cost_cents=preset["cost_cents"])


def cmd_set_budget(args):
    BUDGET_FILE.parent.mkdir(parents=True, exist_ok=True)
    budget = {"budget_cents": args.cents, "log": []}
    if BUDGET_FILE.exists():
        old = json.loads(BUDGET_FILE.read_text())
        budget["log"] = old.get("log", [])
    BUDGET_FILE.write_text(json.dumps(budget, indent=2) + "\n")
    spent = _spent_total(budget)
    print(json.dumps({"ok": True, "budget_cents": args.cents, "spent_cents": spent, "remaining_cents": args.cents - spent}))


def main():
    parser = argparse.ArgumentParser(description="Asset Generator — images (ModelScope Qwen) and GLBs (Tripo3D)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_img = sub.add_parser("image", help="Generate a PNG image (2¢ standard, 7¢ pro)")
    p_img.add_argument("--prompt", required=True, help="Full image generation prompt")
    p_img.add_argument("--model", choices=list(IMAGE_MODELS.keys()), default="standard",
                       help="Model tier: standard (2¢, fast) or pro (7¢, higher quality). Default: standard.")
    p_img.add_argument("--size", choices=IMAGE_SIZES, default="1024x1024",
                       help="Resolution. Default: 1024x1024.")
    p_img.add_argument("--aspect-ratio", choices=IMAGE_ASPECT_RATIOS, default="1:1",
                       help="Aspect ratio. Default: 1:1")
    p_img.add_argument("--image", default=None, help="Reference image for image-to-image edit")
    p_img.add_argument("-o", "--output", required=True, help="Output PNG path")
    p_img.set_defaults(func=cmd_image)

    p_vid = sub.add_parser("video", help="Generate MP4 video from prompt + reference image (5¢/sec)")
    p_vid.add_argument("--prompt", required=True, help="Video generation prompt")
    p_vid.add_argument("--image", required=True, help="Reference image path (starting frame)")
    p_vid.add_argument("--duration", type=int, required=True, help="Duration in seconds (1-15)")
    p_vid.add_argument("--resolution", choices=["480p", "720p"], default="720p",
                       help="Video resolution. Default: 720p")
    p_vid.add_argument("-o", "--output", required=True, help="Output MP4 path")
    p_vid.set_defaults(func=cmd_video)

    p_glb = sub.add_parser("glb", help="Convert PNG to GLB 3D model (30-60 cents)")
    p_glb.add_argument("--image", required=True, help="Input PNG path")
    p_glb.add_argument("--quality", default="medium", choices=list(QUALITY_PRESETS.keys()), help="Quality preset")
    p_glb.add_argument("-o", "--output", required=True, help="Output GLB path")
    p_glb.set_defaults(func=cmd_glb)

    p_budget = sub.add_parser("set_budget", help="Set the asset generation budget in cents")
    p_budget.add_argument("cents", type=int, help="Budget in cents")
    p_budget.set_defaults(func=cmd_set_budget)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
