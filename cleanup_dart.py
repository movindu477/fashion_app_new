import os
import re

def clean_dart_files(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Remove double commas potentially separated by whitespace or newlines
                new_content = re.sub(r",\s*,", ",", content)
                
                # Remove empty lines containing only a comma and whitespace
                new_content = re.sub(r"\n\s*,\s*\n", "\n", new_content)
                
                # Remove google_fonts imports
                new_content = re.sub(r"import 'package:google_fonts/google_fonts.dart';\n?", "", new_content)

                if new_content != content:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(new_content)

if __name__ == "__main__":
    clean_dart_files("lib")
