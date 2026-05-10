import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { randomUUID } from "crypto";

const s3  = new S3Client();
const ddb = new DynamoDBClient();

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Content-Type": "application/json"
};

export const handler = async () => {
  const memeId = randomUUID();
  const key    = `uploads/${memeId}.jpg`;

  // 1. Generate a presigned PUT URL — browser uploads the image directly to S3
  const uploadUrl = await getSignedUrl(
    s3,
    new PutObjectCommand({
      Bucket: process.env.INPUT_BUCKET,
      Key: key,
      ContentType: "image/jpeg"
    }),
    { expiresIn: 900 } // 15 minutes
  );

  // 2. Create a PENDING record so the status endpoint has something to return
  await ddb.send(new PutItemCommand({
    TableName: process.env.TABLE_NAME,
    Item: {
      MemeId:    { S: memeId },
      Status:    { S: "PENDING" },
      CreatedAt: { S: new Date().toISOString() }
    }
  }));

  return {
    statusCode: 200,
    headers: CORS,
    body: JSON.stringify({ memeId, uploadUrl })
  };
};
