import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const smClient = new SecretsManagerClient();

export const handler = async (event) => {
  const { labels } = event;
  let apiKey = "";

  // 1. Securely fetch the API key from AWS Secrets Manager at runtime
  try {
    const secretRes = await smClient.send(new GetSecretValueCommand({
      SecretId: process.env.SECRET_ID 
    }));
    apiKey = secretRes.SecretString;
  } catch (error) {
    console.error("Failed to fetch secret from Secrets Manager:", error);
    throw new Error("Missing Gemini API Key");
  }

  // 2. Build the AI Prompt for classic two-line top/bottom meme text
  const prompt = `You are a sarcastic, internet-culture meme generator.
  I have an image with the following labels: ${labels.join(', ')}.
  Write a classic two-line meme caption in the style of popular internet memes.
  Line 1 (top text): A short setup or context (maximum 5 words, ALL CAPS).
  Line 2 (bottom text): A short, funny punchline (maximum 5 words, ALL CAPS).
  Return ONLY the two lines separated by a pipe character |
  Example format: WHEN YOU SEE IT|YOUR BRAIN EXPLODES
  Do not include quotes, newlines, or any other text.`;

  let topText = "WHEN YOU SEE IT";
  let bottomText = "BOTTOM TEXT";

  // 3. Call Gemini
  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }]
      })
    });

    const data = await response.json();
    
    if (data.candidates && data.candidates[0].content) {
      const raw = data.candidates[0].content.parts[0].text.trim();
      const parts = raw.split('|');
      topText    = (parts[0] || topText).trim().replace(/^"|"$/g, '');
      bottomText = (parts[1] || bottomText).trim().replace(/^"|"$/g, '');
    } else {
      console.error("Unexpected API response:", JSON.stringify(data));
    }
  } catch (error) {
    console.error("Failed to generate AI caption:", error);
  }

  return { ...event, topText, bottomText };
};