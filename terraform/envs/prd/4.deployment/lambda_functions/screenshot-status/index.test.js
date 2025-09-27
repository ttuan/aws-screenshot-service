const { mockClient } = require('aws-sdk-client-mock');
const { DynamoDBClient, GetItemCommand } = require('@aws-sdk/client-dynamodb');
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

// Mock AWS SDK clients
const dynamoMock = mockClient(DynamoDBClient);
const s3Mock = mockClient(S3Client);

// Mock getSignedUrl
jest.mock('@aws-sdk/s3-request-presigner');

// Import the handler after mocking
const { handler } = require('./index');

describe('Screenshot Status Lambda', () => {
  beforeEach(() => {
    // Reset all mocks
    dynamoMock.reset();
    s3Mock.reset();
    getSignedUrl.mockReset();

    // Set environment variables
    process.env.DYNAMODB_TABLE_NAME = 'test-table';
    process.env.S3_BUCKET_NAME = 'test-bucket';
    process.env.NODE_ENV = 'test';
  });

  describe('Input validation', () => {
    test('should return 400 when jobId is missing', async () => {
      const event = {
        pathParameters: {}
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('jobId is required in path parameters');
    });

    test('should return 400 when pathParameters is null', async () => {
      const event = {
        pathParameters: null
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
    });
  });

  describe('DynamoDB interactions', () => {
    test('should return 404 when job not found', async () => {
      const event = {
        pathParameters: { jobId: 'non-existent-job' }
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: null });

      const result = await handler(event);

      expect(result.statusCode).toBe(404);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Job not found');
      expect(body.jobId).toBe('non-existent-job');
    });

    test('should return job status when found', async () => {
      const event = {
        pathParameters: { jobId: 'test-job-123' }
      };

      const mockItem = {
        jobId: { S: 'test-job-123' },
        status: { S: 'pending' },
        createdAt: { S: '2023-01-01T00:00:00Z' }
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: mockItem });

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.jobId).toBe('test-job-123');
      expect(body.status).toBe('pending');
      expect(body.message).toBe('Job is queued and waiting to be processed');
    });

    test('should include error message for failed jobs', async () => {
      const event = {
        pathParameters: { jobId: 'failed-job' }
      };

      const mockItem = {
        jobId: { S: 'failed-job' },
        status: { S: 'failed' },
        createdAt: { S: '2023-01-01T00:00:00Z' },
        error: { S: 'Network timeout' }
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: mockItem });

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.status).toBe('failed');
      expect(body.error).toBe('Network timeout');
      expect(body.message).toBe('Job failed to complete');
    });
  });

  describe('S3 URL generation', () => {
    test('should generate presigned URL for completed jobs', async () => {
      const event = {
        pathParameters: { jobId: 'completed-job' }
      };

      const mockItem = {
        jobId: { S: 'completed-job' },
        status: { S: 'completed' },
        createdAt: { S: '2023-01-01T00:00:00Z' },
        completedAt: { S: '2023-01-01T00:05:00Z' },
        s3Path: { S: 'screenshots/completed-job.png' }
      };

      const mockPresignedUrl = 'https://test-bucket.s3.amazonaws.com/screenshots/completed-job.png?signature=xyz';

      dynamoMock.on(GetItemCommand).resolves({ Item: mockItem });
      getSignedUrl.mockResolvedValue(mockPresignedUrl);

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.status).toBe('completed');
      expect(body.publicUrl).toBe(mockPresignedUrl);
      expect(body.expiresAt).toBeDefined();
      expect(body.completedAt).toBe('2023-01-01T00:05:00Z');
    });

    test('should handle S3 URL generation failure gracefully', async () => {
      const event = {
        pathParameters: { jobId: 'completed-job' }
      };

      const mockItem = {
        jobId: { S: 'completed-job' },
        status: { S: 'completed' },
        createdAt: { S: '2023-01-01T00:00:00Z' },
        s3Path: { S: 'screenshots/completed-job.png' }
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: mockItem });
      getSignedUrl.mockRejectedValue(new Error('S3 access denied'));

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.status).toBe('completed');
      expect(body.warning).toBe('Screenshot completed but URL generation failed');
      expect(body.publicUrl).toBeUndefined();
    });

    test('should not generate URL for completed jobs without S3 path', async () => {
      const event = {
        pathParameters: { jobId: 'completed-job-no-s3' }
      };

      const mockItem = {
        jobId: { S: 'completed-job-no-s3' },
        status: { S: 'completed' },
        createdAt: { S: '2023-01-01T00:00:00Z' }
        // No s3Path
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: mockItem });

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.status).toBe('completed');
      expect(body.publicUrl).toBeUndefined();
      expect(body.warning).toBeUndefined();
    });
  });

  describe('Error handling', () => {
    test('should handle DynamoDB errors gracefully', async () => {
      const event = {
        pathParameters: { jobId: 'test-job' }
      };

      dynamoMock.on(GetItemCommand).rejects(new Error('DynamoDB connection failed'));

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Internal server error');
    });

    test('should include error details in development mode', async () => {
      process.env.NODE_ENV = 'development';

      const event = {
        pathParameters: { jobId: 'test-job' }
      };

      dynamoMock.on(GetItemCommand).rejects(new Error('Specific error message'));

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.details).toBe('Specific error message');
    });
  });

  describe('CORS headers', () => {
    test('should include proper CORS headers in all responses', async () => {
      const event = {
        pathParameters: { jobId: 'test-job' }
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: null });

      const result = await handler(event);

      expect(result.headers).toEqual({
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,OPTIONS'
      });
    });
  });

  describe('Status messages', () => {
    test.each([
      ['pending', 'Job is queued and waiting to be processed'],
      ['processing', 'Job is currently being processed'],
      ['completed', 'Job completed successfully'],
      ['failed', 'Job failed to complete'],
      ['unknown', 'Unknown status']
    ])('should return correct message for status: %s', async (status, expectedMessage) => {
      const event = {
        pathParameters: { jobId: 'test-job' }
      };

      const mockItem = {
        jobId: { S: 'test-job' },
        status: { S: status },
        createdAt: { S: '2023-01-01T00:00:00Z' }
      };

      dynamoMock.on(GetItemCommand).resolves({ Item: mockItem });

      const result = await handler(event);

      expect(result.statusCode).toBe(200);
      const body = JSON.parse(result.body);
      expect(body.message).toBe(expectedMessage);
    });
  });
});
