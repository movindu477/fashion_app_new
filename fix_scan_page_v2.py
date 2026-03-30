import os
import re

def fix_all_duplicated_font_weights(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()

                # Fix duplicated fontWeight: FontWeight.w200 in scan_page.dart specifically if it happened twice
                # Example:
                # TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w200, 
                # ...
                # fontSize: 12, fontWeight: FontWeight.w200,
                
                # First, remove the specific dynamic one that my last script converted to w200 but left both.
                new_content = content
                
                # Pattern: fontWeight: FontWeight.w200, followed by optional text then another fontWeight: FontWeight.w200,
                # We only want one per TextStyle.
                # However, TextStyles are small. Let's just do a greedy match on the duplicates.
                
                # Removing any line that has JUST "fontWeight: FontWeight.w200," and is following another one in the same block.
                # Since we can't easily parse blocks with regex, let's find the specific sequence for ChoiceChips.
                
                # Sequence:
                # labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w200, 
                #   color: Colors.black,
                #   fontSize: 12, fontWeight: FontWeight.w200,
                # ),
                
                pattern = r"labelStyle: TextStyle\(fontFamily: 'Poppins', fontWeight: FontWeight\.w200,\s*(color: Colors\.black,\s*fontSize: 12,)\s*fontWeight: FontWeight\.w200,"
                new_content = re.sub(pattern, r"labelStyle: TextStyle(\n                                fontFamily: 'Poppins',\n                                fontWeight: FontWeight.w200,\n                                \1", new_content, flags=re.DOTALL)

                if new_content != content:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(new_content)

if __name__ == "__main__":
    fix_all_duplicated_font_weights("lib")
