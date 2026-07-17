from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "mascot-gifs"

SOURCES = [
    (Path("/Users/steven/.codex/generated_images/019f6dcc-7381-7331-a68e-df334b2a03be/exec-97670f1f-460c-4d83-a205-1f9cf23ea37c.png"), "coral-wave.gif"),
    (Path("/Users/steven/.codex/generated_images/019f6dcc-7381-7331-a68e-df334b2a03be/exec-5b873959-13c6-4829-a640-e6f2a73ea6b9.png"), "teal-bounce.gif"),
    (Path("/Users/steven/.codex/generated_images/019f6dcc-7381-7331-a68e-df334b2a03be/exec-2d77c6fe-c05d-4438-9e52-780f3cce7c66.png"), "yellow-jump.gif"),
]


def remove_magenta(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, _ in rgba.getdata():
        is_key = red > 210 and blue > 165 and green < 105 and red > green * 2 and blue > green * 1.7
        pixels.append((red, green, blue, 0 if is_key else 255))
    rgba.putdata(pixels)
    return rgba


def make_gif(source: Path, filename: str) -> None:
    sheet = Image.open(source)
    frame_width = sheet.width // 8
    raw_frames = [
        remove_magenta(sheet.crop((index * frame_width, 0, (index + 1) * frame_width, sheet.height)))
        for index in range(8)
    ]

    boxes = [frame.getbbox() for frame in raw_frames if frame.getbbox()]
    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    subject_width = right - left
    subject_height = bottom - top
    scale = max(1, min(3, 272 // max(subject_width, subject_height)))

    frames = []
    for frame in raw_frames:
        crop = frame.crop((left, top, right, bottom))
        crop = crop.resize((subject_width * scale, subject_height * scale), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (320, 320), (0, 0, 0, 0))
        x = (320 - crop.width) // 2
        y = (320 - crop.height) // 2
        canvas.alpha_composite(crop, (x, y))
        frames.append(canvas)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        OUTPUT / filename,
        save_all=True,
        append_images=frames[1:],
        duration=130,
        loop=0,
        disposal=2,
        transparency=0,
        optimize=False,
    )


for source, filename in SOURCES:
    make_gif(source, filename)
