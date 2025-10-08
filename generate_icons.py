from PIL import Image
import os

# Define icon sizes for different densities
icon_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192
}

# Paths
source_image = 'assets/images/Logo.png'
res_path = 'android/app/src/main/res'

# Open the source image
img = Image.open(source_image)

# Generate icons for each density
for folder, size in icon_sizes.items():
    # Create folder path
    folder_path = os.path.join(res_path, folder)
    
    # Resize image
    resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
    
    # Save as ic_launcher.png
    output_path = os.path.join(folder_path, 'ic_launcher.png')
    resized_img.save(output_path, 'PNG')
    print(f'Generated: {output_path} ({size}x{size})')

print('\nAll launcher icons generated successfully!')
