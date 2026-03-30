import os
import re

def fix_duplicated_font_weight(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Find cases where a TextStyle has two fontWeight parameters.
    # Pattern: TextStyle(..., fontWeight: FontWeight.w200, ..., fontWeight: ...)
    # 
    # This matches the labelStyle pattern I saw:
    # labelStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w200, 
    #   color: Colors.black,
    #   fontSize: 12,
    #   fontWeight: isSelected
    #       ? FontWeight.bold
    #       : FontWeight.normal,
    # ),
    
    # Let's use a simpler approach: if we find fontWeight twice in the same block, keep only the first (w200).
    
    def replacement_logic(match):
        block = match.group(0)
        # Find all fontWeight occurrences in the block
        # We want to remove any that are NOT the first one if the first one is FontWeight.w200
        # Actually, let's just find the pattern and replace it.
        
        # This regex matches the multi-line fontWeight duplicated in ChoiceChips
        pattern = r"fontWeight:\s*FontWeight\.w200,\s*(.*?)(fontWeight:\s*isSelected\s*\?\s*FontWeight\.\w+\s*:\s*FontWeight\.\w+,)"
        new_block = re.sub(pattern, r"fontWeight: FontWeight.w200, \1", block, flags=re.DOTALL)
        return new_block

    # Apply specifically to TextStyles in scan_page.dart
    # We find TextStyle blocks using a simple parenthesis counter or just a broad search.
    # Actually, let's just do a blanket replacement in the whole content.
    
    new_content = re.sub(r"fontWeight:\s*FontWeight\.w200,\s*(.*?)(fontWeight:\s*isSelected\s*\?\s*FontWeight\.\w+\s*:\s*FontWeight\.\w+,)", 
                         r"\1 fontWeight: FontWeight.w200,", content, flags=re.DOTALL)

    # Wait, the above might leave a trailing comma or messy parameters.
    # Let's try again with a cleaner approach for ChoiceChips specifically.
    
    # We want TO REMOVE the isSelected?...: FontWeight.normal part and keep FontWeight.w200.
    new_content = re.sub(r"fontWeight:\s*FontWeight\.w200,\s*(.*?)(color: Colors\.black,.*?fontSize: 12,)\s*fontWeight:\s*isSelected\s*\?\s*FontWeight\.\w+\s*:\s*FontWeight\.\w+,",
                         r"\1 \2 fontWeight: FontWeight.w200,", content, flags=re.DOTALL)

    if new_content != content:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)

if __name__ == "__main__":
    fix_duplicated_font_weight("lib/views/scan_page.dart")
