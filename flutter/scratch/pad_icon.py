from PIL import Image
import os

def add_padding(image_path, output_path, padding_ratio=0.6):
    img = Image.open(image_path)
    img = img.convert("RGBA")
    
    width, height = img.size
    
    # Calculate new size with padding
    new_width = int(width * (1 + padding_ratio * 2))
    new_height = int(height * (1 + padding_ratio * 2))
    
    # Create new transparent background
    new_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    
    # Paste original image in the center
    offset = ((new_width - width) // 2, (new_height - height) // 2)
    new_img.paste(img, offset)
    
    new_img.save(output_path)
    print(f"Success: Saved padded image to {output_path}")

if __name__ == "__main__":
    input_file = r"F:\val\ESP32S3lirik2\flutter\assets\icon\playstore.png"
    output_file = r"F:\val\ESP32S3lirik2\flutter\assets\icon\playstore_padded.png"
    
    if os.path.exists(input_file):
        try:
            add_padding(input_file, output_file)
        except Exception as e:
            print(f"Error: {e}")
    else:
        print(f"Error: {input_file} not found")
