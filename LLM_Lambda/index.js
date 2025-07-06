const axios = require("axios");
// const { Configuration, OpenAIApi } = require("openai");

const EMBEDDING_URL = process.env.EMBEDDING_SERVER_URL + "/embed";
const SEARCH_URL = process.env.EMBEDDING_SERVER_URL + "/search";
const OpenAI = require("openai");

exports.handler = async (event) => {
  try {
    // ✅ Handle CORS Preflight
    if (event.requestContext.http.method === "OPTIONS") {
      return corsResponse(200, "");
    }

    const body = JSON.parse(event.body);
    const query = body.query;
    const fileName = body.fileName;

    if (!query || !fileName) {
      return corsResponse(400, { error: "Missing query or fileName" });
    }

    // 🔍 Search vector index
    const searchResponse = await axios.post(`${SEARCH_URL}`, {
      query,
      file_name: fileName,
    });

    const topChunks = searchResponse.data.results || [];
    const context = topChunks.map((c) => c.chunk).join("\n\n");
    console.log("Context:", context);
    console.log("Top chunks:", topChunks);
    console.log("Saajid coolboy");
    // 🧠 Call LLM with retrieved context
    const answer = await callGemini(query, context);

    return corsResponse(200, {
      message: "Query processed successfully",
      topChunks,
      context,
      answer,
    });
  } catch (err) {
    console.error("Query Lambda error:", err.message);
    return corsResponse(500, { error: "Internal Server Error" });
  }
};

// ✅ Helper: OpenAI LLM call
async function callGemini(query, context) {
  console.log("sajContext:", context);
  console.log("sajQuery:", query);
//    context = "AWS, Azure, and GCP are major cloud providers.";
//  query = "What are the cloud technologies mentioned?";
  try {
    const GEMINI_API_KEY = 'AIzaSyBunFAtmkpfL5jbgCDAYDZv-F4RjXpkkak';
    const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-002:generateContent?key=${GEMINI_API_KEY}`;

    const response = await axios.post(GEMINI_URL, {
      contents: [
        {
          role: "user",
          parts: [
            {
              text:
`You are a helpful assistant. Only use the context provided below to answer the user's question.
Do not use external knowledge.

Context:
${context}

Question:
${query}

Answer:`
            }
          ]
        }
      ]
    });

    const answer = response.data.candidates?.[0]?.content?.parts?.[0]?.text || "No answer generated.";
    return answer;

  } catch (error) {
    console.error("Error calling Gemini API:", error.response?.data || error.message);
    throw new Error("Failed to call Gemini API");
  }
}



// ✅ Helper: CORS-enabled JSON response
function corsResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "*",
      "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS,PATCH",
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  };
}
