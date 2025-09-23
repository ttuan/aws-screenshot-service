const { DynamoDBClient, GetItemCommand } = require("@aws-sdk/client-dynamodb");
const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");

const dynamoClient = new DynamoDBClient({});
const s3Client = new S3Client({});

exports.handler = async (event) => {
  try {
    console.log("Received event:", JSON.stringify(event, null, 2));

    // Extract jobId from path parameters
    const jobId = event.pathParameters?.jobId;

    if (!jobId) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
          "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        body: JSON.stringify({
          success: false,
          error: "jobId is required in path parameters",
        }),
      };
    }

    // Query DynamoDB for job status
    const getItemCommand = new GetItemCommand({
      TableName: process.env.DYNAMODB_TABLE_NAME,
      Key: {
        jobId: { S: jobId },
      },
    });

    const dynamoResponse = await dynamoClient.send(getItemCommand);

    if (!dynamoResponse.Item) {
      return {
        statusCode: 404,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
          "Access-Control-Allow-Methods": "GET,OPTIONS",
        },
        body: JSON.stringify({
          success: false,
          error: "Job not found",
          jobId: jobId,
        }),
      };
    }

    // Parse DynamoDB item
    const item = dynamoResponse.Item;
    const status = item.status?.S;
    const createdAt = item.createdAt?.S;
    const completedAt = item.completedAt?.S;
    const errorMessage = item.error?.S;
    const s3Key = item.s3Path?.S;

    // Build response object
    const response = {
      success: true,
      jobId: jobId,
      status: status,
      message: getStatusMessage(status),
      createdAt: createdAt,
    };

    // Add completedAt if available
    if (completedAt) {
      response.completedAt = completedAt;
    }

    // Add error if failed
    if (status === "failed" && errorMessage) {
      response.error = errorMessage;
    }

    // Generate presigned URL if job is completed and S3 key exists
    if (status === "completed" && s3Key) {
      try {
        const presignedUrl = await getSignedUrl(
          s3Client,
          new GetObjectCommand({
            Bucket: process.env.S3_BUCKET_NAME,
            Key: s3Key,
          }),
          { expiresIn: 86400 }, // 24 hours
        );

        response.publicUrl = presignedUrl;
        response.expiresAt = new Date(Date.now() + 86400 * 1000).toISOString(); // 24 hours from now
      } catch (s3Error) {
        console.error("Error generating presigned URL:", s3Error);
        // Don't fail the entire request if S3 URL generation fails
        response.warning = "Screenshot completed but URL generation failed";
      }
    }

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
      },
      body: JSON.stringify(response),
    };
  } catch (error) {
    console.error("Error processing status request:", error);

    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
      },
      body: JSON.stringify({
        success: false,
        error: "Internal server error",
        details:
          process.env.NODE_ENV === "development" ? error.message : undefined,
      }),
    };
  }
};

function getStatusMessage(status) {
  switch (status) {
    case "pending":
      return "Job is queued and waiting to be processed";
    case "processing":
      return "Job is currently being processed";
    case "completed":
      return "Job completed successfully";
    case "failed":
      return "Job failed to complete";
    default:
      return "Unknown status";
  }
}

