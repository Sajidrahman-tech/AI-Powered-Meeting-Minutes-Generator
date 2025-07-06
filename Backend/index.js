const AWS = require('aws-sdk');

exports.handler = async (event) => {
  console.log("🔹 Incoming Event:", JSON.stringify(event));

  try {
    const body = JSON.parse(event.body);
    console.log("✅ Parsed Body:", body);

    const { fileName, contentType } = body;
    console.log("📁 File Name:", fileName);
    console.log("📦 Content Type:", contentType);

    const s3 = new AWS.S3();
    console.log("🔐 S3 Bucket:", process.env.S3_BUCKET_NAME);

    const url = await s3.getSignedUrlPromise('putObject', {
      Bucket: process.env.S3_BUCKET_NAME,
      Key: fileName,
      ContentType: contentType,
      Expires: 300,
    });

    console.log("✅ Pre-signed URL generated:", url);

    return {
      statusCode: 200,
      body: JSON.stringify({ url }),
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*",
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET,PUT",
      },
    };
  } catch (error) {
    console.error("❌ Error generating signed URL:", error.message);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*",
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET,PUT",
      },
    };
  }
};