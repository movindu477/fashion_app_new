
from PIL import Image, ImageOps, ImageDraw
import os

path = r'c:\Users\USER\Desktop\GitHub Projects\fashion_app_new\assets\images\logo.png'

try:
    img = Image.open(path)
    print(f"Original size: {img.size}")
    
    # Check if there is transparent padding to crop (to 'increase size' of visual logo)
    bbox = img.getbbox()
    if bbox:
        # Calculate current content size
        content_width = bbox[2] - bbox[0]
        content_height = bbox[3] - bbox[1]
        print(f"Content bbox: {bbox} (Dimensions: {content_width}x{content_height})")
    
except Exception as e:
    print(f"Error: {e}")
