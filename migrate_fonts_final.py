import os
import re

def migrate_fonts_final(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Replace any FontWeight override with w200
                new_content = re.sub(r"fontWeight:\s*FontWeight\.\w+", "fontWeight: FontWeight.w200", content)
                
                # Replace GoogleFonts with TextStyle if any remained
                new_content = re.sub(r"GoogleFonts\.[a-zA-Z]+\(", "TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w200, ", new_content)

                if new_content != content:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(new_content)

if __name__ == "__main__":
    migrate_fonts_final("lib")
