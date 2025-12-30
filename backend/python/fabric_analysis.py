from flask import Flask, request, jsonify
import cv2
import numpy as np
from sklearn.cluster import KMeans
import os

app = Flask(__name__)

def extract_dominant_colors(image_path, k=3):
    # Convert Windows slashes
    image_path = image_path.replace("\\", "/")

    # Get absolute path to project root
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    # BASE_DIR -> backend/

    full_image_path = os.path.join(BASE_DIR, image_path)

    print("Reading image from absolute path:", full_image_path)

    image = cv2.imread(full_image_path)

    if image is None:
        raise ValueError(f"Could not read image from path: {full_image_path}")

    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    pixels = image.reshape((-1, 3))

    kmeans = KMeans(n_clusters=k, random_state=42)
    kmeans.fit(pixels)

    colors = kmeans.cluster_centers_.astype(int)
    return colors.tolist()

@app.route('/analyze-fabric', methods=['POST'])
def analyze_fabric():
    try:
        data = request.json
        print("Received data from Node.js:", data)

        image_path = data.get('image_path') if data else None
        if not image_path:
            return jsonify({'status': 'error', 'error': 'Image path missing'}), 400

        colors = extract_dominant_colors(image_path)

        print("Dominant colors:", colors)

        return jsonify({
            'status': 'success',
            'dominant_colors': colors
        })

    except Exception as e:
        print("Error in analyze_fabric:", str(e))
        return jsonify({
            'status': 'error',
            'error': str(e)
        }), 500

if __name__ == '__main__':
    app.run(port=5000)

