"""Generate the VM Manager Windows icon and its preview (requires Pillow)."""

from pathlib import Path

from PIL import Image, ImageDraw


HERE = Path(__file__).resolve().parent
SIZE = 1024


def main() -> None:
    gradient = Image.new("RGBA", (SIZE, SIZE))
    pixels = gradient.load()
    for y in range(SIZE):
        for x in range(SIZE):
            blend = (x + y) / (2 * (SIZE - 1))
            pixels[x, y] = (
                int(8 + 19 * blend),
                int(22 + 9 * blend),
                int(57 + 80 * blend),
                255,
            )

    mask = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(mask).rounded_rectangle((36, 36, 988, 988), radius=205, fill=255)
    icon = Image.new("RGBA", (SIZE, SIZE))
    icon.paste(gradient, (0, 0), mask)
    draw = ImageDraw.Draw(icon)

    draw.rounded_rectangle((83, 83, 941, 941), radius=168, outline=(74, 154, 255, 190), width=15)
    draw.rounded_rectangle((178, 215, 846, 702), radius=60, fill=(12, 28, 69, 255), outline=(75, 215, 255, 255), width=36)
    draw.rounded_rectangle((232, 267, 792, 649), radius=25, fill=(13, 32, 78, 255))

    draw.rounded_rectangle((325, 361, 498, 534), radius=22, fill=(29, 100, 176, 255), outline=(119, 237, 255, 255), width=25)
    draw.rounded_rectangle((526, 361, 699, 534), radius=22, fill=(72, 67, 165, 255), outline=(168, 151, 255, 255), width=25)
    draw.line((512, 704, 512, 769), fill=(94, 204, 255, 255), width=34)
    draw.rounded_rectangle((354, 762, 670, 810), radius=24, fill=(94, 204, 255, 255))

    # Lazarus' icon reader expects classic DIB frames, not PNG frames inside ICO.
    icon.save(HERE / "VMManager.ico", format="ICO", bitmap_format="bmp", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    icon.resize((256, 256), Image.Resampling.LANCZOS).save(HERE / "icon-preview.png")


if __name__ == "__main__":
    main()
