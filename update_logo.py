
import cv2
import numpy as np
import os
import sys

path = r'c:\Users\USER\Desktop\GitHub Projects\fashion_app_new\assets\images\logo.png'

try:
    print(f"Processing: {path}")
    # Read with alpha channel
    img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    
    if img is None:
        print("Error: Could not load image")
        sys.exit(1)

    h, w = img.shape[:2]
    channels = img.shape[2] if len(img.shape) > 2 else 1
    print(f"Original size: {w}x{h}, Channels: {channels}")
    
    # Ensure 4 channels
    if channels == 3:
        b, g, r = cv2.split(img)
        alpha = np.ones((h, w), dtype=np.uint8) * 255
        img = cv2.merge([b, g, r, alpha])
    elif channels == 1:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGRA)

    # Calculate content box (based on alpha > 0)
    alpha = img[:, :, 3]
    coords = cv2.findNonZero(alpha)
    
    if coords is not None:
        x, y, w_c, h_c = cv2.boundingRect(coords)
        print(f"Content box: {w_c}x{h_c} at {x},{y}")
        
        # Crop (Increase size visually)
        pad = 20 # Keep a little padding
        x_start = max(0, x - pad)
        y_start = max(0, y - pad)
        width_crop = min(w - x_start, w_c + 2*pad)
        height_crop = min(h - y_start, h_c + 2*pad)
        
        # Ensure square crop if possible or just crop
        # Better: Crop tight, then paste into square 512x512
        cropped = img[y_start:y_start+height_crop, x_start:x_start+width_crop]
        
        target_size = 512
        # Resize maintaining aspect ratio to fit in target_size
        ch, cw = cropped.shape[:2]
        ratio = min(target_size/ch, target_size/cw)
        new_h, new_w = int(ch * ratio), int(cw * ratio)
        resized_content = cv2.resize(cropped, (new_w, new_h), interpolation=cv2.INTER_AREA)
        
        # Create blank 512x512
        final_img = np.zeros((target_size, target_size, 4), dtype=np.uint8)
        
        # Center processed content
        y_off = (target_size - new_h) // 2
        x_off = (target_size - new_w) // 2
        
        # Paste content
        # Check alpha compositing? No, just copy for now logic
        # But wait, resizing might have made alpha non-binary.
        
        # Copy content into center
        final_img[y_off:y_off+new_h, x_off:x_off+new_w] = resized_content
        
        # Add Border Radius Mask
        # Create mask
        mask = np.zeros((target_size, target_size), dtype=np.uint8)
        r = 60 # 60px radius for 512px icon (visible rounding)
        
        # Draw rounded rect mask
        # Main rects
        cv2.rectangle(mask, (r, 0), (target_size-r, target_size), 255, -1)
        cv2.rectangle(mask, (0, r), (target_size, target_size-r), 255, -1)
        # Corners
        cv2.circle(mask, (r, r), r, 255, -1)
        cv2.circle(mask, (target_size-r, r), r, 255, -1)
        cv2.circle(mask, (r, target_size-r), r, 255, -1)
        cv2.circle(mask, (target_size-r, target_size-r), r, 255, -1)
        
        # Apply mask to alpha channel
        final_img[:, :, 3] = cv2.bitwise_and(final_img[:, :, 3], mask)
        
        # Save
        cv2.imwrite(path, final_img)
        print("Successfully processed logo.png and saved")
        
    else:
        print("Image is fully transparent?")

except Exception as e:
    import traceback
    traceback.print_exc()
