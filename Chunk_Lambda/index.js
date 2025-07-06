const AWS = require('aws-sdk');
const pdf = require('pdf-parse');

const s3 = new AWS.S3();

exports.handler = async (event) => {
  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    console.log("Processing file:", key);

    try {
      const file = await s3.getObject({ Bucket: bucket, Key: key }).promise();
      const data = await pdf(file.Body);

      const text = data.text;
      console.log("Extracted text length:", text.length);

      const chunks = chunkText(text);
      console.log(`Generated ${chunks.length} chunks`);

      // Optional: send chunks to DynamoDB, another Lambda, or save to S3
    } catch (error) {
      console.error("Failed to process PDF:", error);
    }
  }
};

// Basic chunking function
function chunkText(text, chunkSize = 1000) {
  const chunks = [];
  for (let i = 0; i < text.length; i += chunkSize) {
    chunks.push(text.substring(i, i + chunkSize));
  }
  return chunks;
}
