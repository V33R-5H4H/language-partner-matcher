import os
from PIL import Image

src_img_path = r"C:\Users\Veer3\.gemini\antigravity-ide\brain\617c34cc-8d0e-4a65-8db8-daf903999767\app_logo_icon_1791214963127.jpg"
base_dir = r"c:\V33R\Programming\College\Sem_7\Project\test1.0\test1"

img = Image.open(src_img_path).convert("RGBA")

# 1. Assets dir
assets_icons_dir = os.path.join(base_dir, "assets", "icons")
os.makedirs(assets_icons_dir, exist_ok=True)
img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(assets_icons_dir, "app_logo.png"), "PNG")
print("Saved assets/icons/app_logo.png")

# 2. Web icons
web_dir = os.path.join(base_dir, "web")
web_icons_dir = os.path.join(web_dir, "icons")
os.makedirs(web_icons_dir, exist_ok=True)

img.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), "PNG")
img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-192.png"), "PNG")
img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-512.png"), "PNG")
img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-192.png"), "PNG")
img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(web_icons_dir, "Icon-maskable-512.png"), "PNG")
print("Saved web icons and favicon")

# 3. Android mipmaps
android_res = os.path.join(base_dir, "android", "app", "src", "main", "res")
mipmaps = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

for folder, size in mipmaps.items():
    folder_path = os.path.join(android_res, folder)
    os.makedirs(folder_path, exist_ok=True)
    out_path = os.path.join(folder_path, "ic_launcher.png")
    img.resize((size, size), Image.Resampling.LANCZOS).save(out_path, "PNG")
    print(f"Saved {folder}/ic_launcher.png ({size}x{size})")

print("All app icons successfully generated!")
