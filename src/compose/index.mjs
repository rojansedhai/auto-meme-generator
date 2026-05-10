import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { DynamoDBClient, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import sharp from "sharp";
import { readFileSync } from "fs";

// Tell fontconfig where to look
process.env.FONTCONFIG_FILE = '/var/task/fonts/fonts.conf';

const s3  = new S3Client();
const ddb = new DynamoDBClient();

// Load font once at module level to avoid re-reading on every invocation
const fontBase64 = readFileSync('./fonts/Anton.ttf').toString('base64');

// Build an SVG text overlay with the Impact-style meme font
const makeSvg = (text, width) => `
  <svg width="${width}" height="100" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <style>
        @font-face {
          font-family: 'Anton';
          src: url('data:font/ttf;base64,${fontBase64}') format('truetype');
        }
        .meme {
          fill: white;
          font-size: 52px;
          font-weight: bold;
          font-family: 'Anton', 'Impact', sans-serif;
          stroke: black;
          stroke-width: 3px;
          paint-order: stroke fill;
        }
      </style>
    </defs>
    <text x="50%" y="74" text-anchor="middle" dominant-baseline="auto" class="meme">${text}</text>
  </svg>`;

export const handler = async (event) => {
  const { bucket, key, memeId, topText, bottomText } = event;

  // 1. Get original image from S3
  const s3Res = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
  const inputBuffer = Buffer.concat(await s3Res.Body.toArray());

  // 2. Get image dimensions
  const { width: imgWidth } = await sharp(inputBuffer).metadata();
  const w = Math.min(imgWidth || 800, 800);

  // 3. Compose: resize + top text (north) + bottom text (south)
  const outputBuffer = await sharp(inputBuffer)
    .resize(800)
    .composite([
      { input: Buffer.from(makeSvg(topText, w)),    gravity: 'north' },
      { input: Buffer.from(makeSvg(bottomText, w)), gravity: 'south' }
    ])
    .jpeg()
    .toBuffer();

  // 4. Upload finished meme — use memeId so status Lambda can find it
  const outputKey = `memes/${memeId}.jpg`;
  await s3.send(new PutObjectCommand({
    Bucket: process.env.OUTPUT_BUCKET,
    Key: outputKey,
    Body: outputBuffer,
    ContentType: "image/jpeg"
  }));

  // 5. UpdateItem: flip the existing PENDING record to COMPLETED
  await ddb.send(new UpdateItemCommand({
    TableName: process.env.TABLE_NAME,
    Key: { MemeId: { S: memeId } },
    UpdateExpression: "SET #st = :s, MemeUrl = :u, TopText = :t, BottomText = :b",
    ExpressionAttributeNames: { "#st": "Status" },
    ExpressionAttributeValues: {
      ":s": { S: "COMPLETED" },
      ":u": { S: outputKey },
      ":t": { S: topText },
      ":b": { S: bottomText }
    }
  }));

  return { status: "Meme Created!", key: outputKey };
};