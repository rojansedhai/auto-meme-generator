import { RekognitionClient, DetectLabelsCommand } from "@aws-sdk/client-rekognition";

const rekog = new RekognitionClient();

export const handler = async (event) => {
  // EventBridge S3 events provide bucket/key in this specific path
  const bucket = event.detail.bucket.name;
  const key = event.detail.object.key;

  // Extract memeId from key path: "uploads/{memeId}.jpg"
  const memeId = key.split('/').pop().replace(/\.[^.]+$/, '');

  const command = new DetectLabelsCommand({
    Image: { S3Object: { Bucket: bucket, Name: key } },
    MaxLabels: 5,
    MinConfidence: 75
  });

  const response = await rekog.send(command);
  const labels = response.Labels.map(l => l.Name.toLowerCase());

  return { bucket, key, memeId, labels };
};