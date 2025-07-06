const AWS = require('aws-sdk');
const pdf = require('pdf-parse');
const axios = require('axios');

const s3 = new AWS.S3();
const EMBEDDING_SERVER_URL = process.env.EMBEDDING_SERVER_URL;

exports.handler = async (event) => {
  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    console.log("Processing file:", key);

    try {
      const file = await s3.getObject({ Bucket: bucket, Key: key }).promise();
      const data = await pdf(file.Body);
      const text = data.text;
      const chunks = chunkText(text);

      console.log(`Extracted ${chunks.length} chunks. Sending to EC2 FAISS server...`);

      const response = await axios.post(`${EMBEDDING_SERVER_URL}/embed`, {
        file_name: key,
        chunks: chunks,
      });
      const returnedEmbeddings = response.data.embeddings;
      console.log(`Received ${returnedEmbeddings.length} embeddings from FAISS server.`);
      console.log("FAISS indexing response:", response.data);
 

    } catch (error) {
      console.error("Lambda error:", error.message || error);
    }
  }
};

function chunkText(text, chunkSize = 1000) {
  const chunks = [];
  for (let i = 0; i < text.length; i += chunkSize) {
    chunks.push(text.substring(i, i + chunkSize));
  }
  return chunks;
}
