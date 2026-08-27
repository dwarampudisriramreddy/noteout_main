import os
import subprocess
import sys

def main():
    print("Converting SVG to PNG...")
    svg_path = "assets/logo.svg"
    png_path = "assets/logo.png"
    
    if not os.path.exists(svg_path):
        print(f"Error: {svg_path} not found.")
        sys.exit(1)

    # Convert SVG to PNG using rsvg-convert (available on this system)
    try:
        subprocess.run(
            ["rsvg-convert", "-w", "1024", "-h", "1024", svg_path, "-o", png_path],
            check=True
        )
        print(f"Successfully created {png_path}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to convert SVG to PNG: {e}")
        sys.exit(1)

    print("Adding flutter_launcher_icons to dev_dependencies...")
    subprocess.run(["flutter", "pub", "add", "dev:flutter_launcher_icons"], check=True)

    print("Configuring flutter_launcher_icons in pubspec.yaml...")
    # Add configuration to pubspec.yaml if not already there
    with open("pubspec.yaml", "r") as f:
        pubspec_content = f.read()

    if "flutter_launcher_icons:" not in pubspec_content:
        config = """
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/logo.png"
"""
        with open("pubspec.yaml", "a") as f:
            f.write(config)
        print("Configuration added.")
    else:
        print("Configuration already exists in pubspec.yaml.")

    print("Generating launcher icons...")
    subprocess.run(["flutter", "pub", "run", "flutter_launcher_icons"], check=True)
    
    print("Done! The app icons have been generated.")

if __name__ == "__main__":
    main()
