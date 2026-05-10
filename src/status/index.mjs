import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { DynamoDBClient, GetItemCommand } from "@aws-sdk/client-dynamodb";

const s3  = new S3Client();
const ddb = new DynamoDBClient();

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json"
};

export const handler = async (event) => {
  const memeId = event.pathParameters?.memeId;

  if (!memeId) {
    return {
      statusCode: 400,
      headers: CORS,
      body: JSON.stringify({ error: "memeId is required" })
    };
  }

  // 1. Look up the meme record in DynamoDB
  const res = await ddb.send(new GetItemCommand({
    TableName: process.env.TABLE_NAME,
    Key: { MemeId: { S: memeId } }
  }));

  if (!res.Item) {
    return {
      statusCode: 404,
      headers: CORS,
      body: JSON.stringify({ error: "Meme not found" })
    };
  }

  const status     = res.Item.Status?.S;
  const memeKey    = res.Item.MemeUrl?.S;
  const topText    = res.Item.TopText?.S;
  const bottomText = res.Item.BottomText?.S;

  // 2. Still processing — tell the frontend to keep polling
  if (status !== "COMPLETED") {
    return {
      statusCode: 200,
      headers: CORS,
      body: JSON.stringify({ status })
    };
  }

  // 3. Done — generate a 1-hour presigned GET URL for the finished meme
  const memeUrl = await getSignedUrl(
    s3,
    new GetObjectCommand({ Bucket: process.env.OUTPUT_BUCKET, Key: memeKey }),
    { expiresIn: 3600 }
  );

  return {
    statusCode: 200,
    headers: CORS,
    body: JSON.stringify({ status, memeUrl, topText, bottomText })
  };
};
