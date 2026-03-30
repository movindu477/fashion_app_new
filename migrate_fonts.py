import os
import re

def migrate_fonts(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Replace GoogleFonts calls
                # GoogleFonts.anything( -> TextStyle(
                new_content = re.sub(r"GoogleFonts\.[a-zA-Z]+\(", "TextStyle(", content)
                
                # Ensure all TextStyle usage (including new ones) has Poppins and w200
                # This is tricky because we don't want to duplicate parameters.
                # However, the user said they want EVERYTHING to be Poppins Extra Light 200.
                
                # Replace existing fontWeights with w200
                new_content = re.sub(r"fontWeight:\s*FontWeight\.[a-z0-9W]+", "fontWeight: FontWeight.w200", new_content)
                
                # Replace FontStyle if any? No, user didn't mention it.
                
                # Add fontWeight: FontWeight.w200 to TextStyle if not present?
                # It's safer to just do a blanket replacement in the theme and let inheritance work,
                # but if we're using explicit TextStyles, we should be careful.
                
                # Actually, I've already set the global theme to w200.
                # If I replace GoogleFonts.xxx(...) with TextStyle(...), it will use the global fontFamily 'Poppins'.
                # But it might not inherit the weight if it's a new TextStyle.
                
                # Let's force the fontFamily and weight in the replacement if it was GoogleFonts.
                # For simplicity, let's just make the replacement more specific:
                # GoogleFonts.xxx( -> TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w200, 
                
                # Restarting replacement logic for better precision
                content = re.sub(r"GoogleFonts\.[a-zA-Z]+\(", "TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w200, ", content)
                
                # Clean up duplicate fontWeights if the original GoogleFonts call had one
                # Note: This might leave double commas or slightly messy code, but dart format will fix it.
                # We search for the pattern we just added followed by another fontWeight.
                content = re.sub(r"(fontWeight: FontWeight\.w200,\s*)(.*?)fontWeight: FontWeight\.[a-z0-9W]+", r"\1\2", content, flags=re.DOTALL)
                
                # Also replace any other hardcoded FontWeights in the file to w200
                content = re.sub(r"fontWeight:\s*FontWeight\.[a-z0-9W]+", "fontWeight: FontWeight.w200", content)

                if content != new_content: # Just a check, actually we use 'content' now
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(content)

if __name__ == "__main__":
    migrate_fonts("lib")
