from PIL import Image
import os
import binascii

def process_icon(image_path, output_path):
    img = Image.open(image_path).convert("RGBA")
    
    # 1. Mendeteksi warna utama (ambil pixel yang tidak transparan di dekat tengah)
    # Kita cari pixel pertama yang punya opacity > 200
    width, height = img.size
    main_color = (255, 255, 255) # Default putih
    
    for y in range(height // 2, height):
        for x in range(width // 2, width):
            r, g, b, a = img.getpixel((x, y))
            if a > 200:
                main_color = (r, g, b)
                break
        else: continue
        break

    # Convert to HEX
    hex_color = '#%02x%02x%02x' % main_color
    print(f"MAIN_COLOR:{hex_color}")

    # 2. Buat background penuh (Fullscreen) dengan warna tersebut
    new_bg = Image.new("RGBA", (width, height), (*main_color, 255))
    
    # 3. Hitung logo dengan padding 7% agar seimbang
    padding_size = int(width * 0.07) 
    logo_size = width - (2 * padding_size)
    
    logo_resized = img.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    # Tempel logo di tengah background
    offset = (padding_size, padding_size)
    new_bg.paste(logo_resized, offset, logo_resized)
    
    new_bg.save(output_path)
    print(f"Success: Saved fullscreen icon to {output_path}")

if __name__ == "__main__":
    input_file = r"F:\val\ESP32S3lirik2\flutter\assets\icon\playstore.png"
    output_file = r"F:\val\ESP32S3lirik2\flutter\assets\icon\playstore_fullscreen.png"
    
    if os.path.exists(input_file):
        process_icon(input_file, output_file)
    else:
        print(f"Error: {input_file} not found")
