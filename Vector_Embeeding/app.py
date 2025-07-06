from flask import Flask, request, jsonify
from sentence_transformers import SentenceTransformer
import faiss
import numpy as np

app = Flask(__name__)

# Load model
print("🔄 Loading model...")
model = SentenceTransformer('all-MiniLM-L6-v2')
dimension = 384
faiss_index = faiss.IndexFlatIP(dimension)  # cosine similarity
print("✅ Model loaded.")

# In-memory metadata store
embedding_store = []
metadata_store = []

@app.route('/', methods=['GET'])
def health_check():
    return "Healthy", 200

@app.route('/embed', methods=['POST'])
def embed_and_store():
    data = request.get_json()
    chunks = data.get('chunks', [])
    file_name = data.get('file_name', 'unknown.pdf')

    if not chunks:
        print("❌ No chunks provided in request.")
        return jsonify({'error': 'No chunks provided'}), 400

    print(f"📄 Received {len(chunks)} chunks for file: {file_name}")
    embeddings = model.encode(chunks, normalize_embeddings=True)
    faiss_index.add(np.array(embeddings))
    embedding_store.extend(embeddings)

    for i, chunk in enumerate(chunks):
        metadata_store.append({
            'file_name': file_name,
            'chunk_index': len(metadata_store),
            'chunk': chunk
        })

    return jsonify({
    'message': f'{len(chunks)} embeddings stored successfully.',
    'embeddings': embeddings.tolist(),  # Ensure it's JSON serializable
    'metadata': metadata_store[-len(chunks):]
})

@app.route('/search', methods=['POST'])
def search_similar_chunks():
    data = request.get_json()
    query = data.get('query', '')
    file_name = data.get('file_name', '')

    if not query or not file_name:
        print("❌ Missing query or file_name.")
        return jsonify({'error': 'Query or file_name missing'}), 400

    print(f"🔍 Searching for query: \"{query}\" in file: {file_name}")
    print(f"🧠 FAISS index size: {faiss_index.ntotal}")
    print(f"📚 Metadata entries: {len(metadata_store)}")

    query_embedding = model.encode([query], normalize_embeddings=True)
    D, I = faiss_index.search(np.array(query_embedding), k=10)

    SIMILARITY_THRESHOLD = 0.0
    filtered_results = []

    for score, i in zip(D[0], I[0]):
        if i >= len(metadata_store):
            continue

        metadata = metadata_store[i]
        print(f"➡️ Match index: {i}, file: {metadata['file_name']}, score: {score:.4f}")

        # Comment this line temporarily for debugging if needed
        if metadata['file_name'] == file_name and score >= SIMILARITY_THRESHOLD:
            result = metadata.copy()
            result['similarity_score'] = float(score)
            filtered_results.append(result)

        if len(filtered_results) >= 5:
            break

    if not filtered_results:
        print("⚠️ No sufficiently similar results found.")
        return jsonify({'results': [], 'message': 'No sufficiently similar chunks found.'})

    print(f"✅ Returning {len(filtered_results)} matching chunks.")
    return jsonify({'results': filtered_results})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
