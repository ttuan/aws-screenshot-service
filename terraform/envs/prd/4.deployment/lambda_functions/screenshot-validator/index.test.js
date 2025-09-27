const { mockClient } = require('aws-sdk-client-mock');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

// Mock AWS SDK clients
const sqsMock = mockClient(SQSClient);

// Import the handler after mocking
const { handler } = require('./index');

describe('Screenshot Validator Lambda', () => {
  beforeEach(() => {
    // Reset all mocks
    sqsMock.reset();

    // Set environment variables
    process.env.SQS_QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue';
    process.env.AWS_REGION = 'us-east-1';
    process.env.NODE_ENV = 'test';
  });

  describe('Input validation', () => {
    test('should return 400 when body is missing', async () => {
      const event = {
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Request body is required');
    });

    test('should return 400 when body is invalid JSON', async () => {
      const event = {
        body: 'invalid json',
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Invalid JSON in request body');
    });

    test('should return 400 when URL is missing', async () => {
      const event = {
        body: JSON.stringify({}),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('URL must be a non-empty string');
    });
  });

  describe('URL validation', () => {
    test('should accept valid HTTPS URL', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).resolves({ MessageId: 'msg-123' });

      const result = await handler(event);

      expect(result.statusCode).toBe(202);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
      expect(body.jobId).toBe('test-request-123');
    });

    test('should accept valid HTTP URL', async () => {
      const event = {
        body: JSON.stringify({
          url: 'http://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).resolves({ MessageId: 'msg-123' });

      const result = await handler(event);

      expect(result.statusCode).toBe(202);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
    });

    test('should reject invalid protocol', async () => {
      const event = {
        body: JSON.stringify({
          url: 'ftp://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('URL must use HTTP or HTTPS protocol');
    });

    test('should reject URL without TLD', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://localhost'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('URL must have a valid domain name with TLD');
    });

    test('should reject too long URL', async () => {
      const longUrl = 'https://example.com/' + 'a'.repeat(2100);
      const event = {
        body: JSON.stringify({
          url: longUrl
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('URL too long (max 2048 characters)');
    });
  });

  describe('Security validations in production', () => {
    beforeEach(() => {
      process.env.NODE_ENV = 'production';
    });

    afterEach(() => {
      process.env.NODE_ENV = 'test';
    });

    test('should reject localhost URLs', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://localhost.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('URL cannot be localhost or private IP');
    });

    test('should reject private IP addresses', async () => {
      const privateIPs = [
        'https://192.168.1.1',
        'https://10.0.0.1',
        'https://172.16.0.1',
        'https://127.0.0.1'
      ];

      for (const url of privateIPs) {
        const event = {
          body: JSON.stringify({ url }),
          requestContext: { requestId: 'test-request-123' }
        };

        const result = await handler(event);

        expect(result.statusCode).toBe(400);
        const body = JSON.parse(result.body);
        expect(body.success).toBe(false);
        expect(body.error).toContain('private IP');
      }
    });

    test('should reject cloud metadata URLs', async () => {
      const metadataUrls = [
        'https://169.254.169.254',
        'https://metadata.google.internal',
        'https://metadata'
      ];

      for (const url of metadataUrls) {
        const event = {
          body: JSON.stringify({ url }),
          requestContext: { requestId: 'test-request-123' }
        };

        const result = await handler(event);

        expect(result.statusCode).toBe(400);
        const body = JSON.parse(result.body);
        expect(body.success).toBe(false);
        expect(body.error).toContain('metadata');
      }
    });

    test('should reject DNS rebinding services', async () => {
      const rebindingUrls = [
        'https://192.168.1.1.xip.io',
        'https://test.nip.io',
        'https://example.sslip.io',
        'https://localhost.example.com'
      ];

      for (const url of rebindingUrls) {
        const event = {
          body: JSON.stringify({ url }),
          requestContext: { requestId: 'test-request-123' }
        };

        const result = await handler(event);

        expect(result.statusCode).toBe(400);
        const body = JSON.parse(result.body);
        expect(body.success).toBe(false);
        expect(body.error).toContain('DNS rebinding') || expect(body.error).toContain('localhost');
      }
    });
  });

  describe('Screenshot options validation', () => {
    test('should accept valid screenshot options', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            width: 1920,
            height: 1080,
            format: 'png',
            quality: 90,
            fullPage: true,
            timeout: 30000,
            waitForNetworkIdle: true
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).resolves({ MessageId: 'msg-123' });

      const result = await handler(event);

      expect(result.statusCode).toBe(202);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(true);
    });

    test('should reject invalid width', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            width: 100 // Too small
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Invalid screenshot options');
      expect(body.details).toContain('Width must be between 320 and 4096 pixels');
    });

    test('should reject invalid height', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            height: 5000 // Too large
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.details).toContain('Height must be between 240 and 4096 pixels');
    });

    test('should reject invalid format', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            format: 'gif' // Not supported
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.details).toContain('Format must be one of: png, jpeg, jpg, webp');
    });

    test('should reject invalid quality', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            quality: 150 // Too high
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.details).toContain('Quality must be between 1 and 100');
    });

    test('should reject invalid timeout', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            timeout: 500 // Too short
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      const result = await handler(event);

      expect(result.statusCode).toBe(400);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.details).toContain('Timeout must be between 1000 and 60000 milliseconds');
    });
  });

  describe('SQS integration', () => {
    test('should send message to SQS with correct format', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com',
          options: {
            width: 1920,
            format: 'png'
          }
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).resolves({ MessageId: 'msg-123' });

      const result = await handler(event);

      expect(result.statusCode).toBe(202);

      // Check that SQS was called with correct parameters
      expect(sqsMock.commandCalls(SendMessageCommand)).toHaveLength(1);
      const sqsCall = sqsMock.commandCalls(SendMessageCommand)[0];

      expect(sqsCall.args[0].input.QueueUrl).toBe(process.env.SQS_QUEUE_URL);

      const messageBody = JSON.parse(sqsCall.args[0].input.MessageBody);
      expect(messageBody.jobId).toBe('test-request-123');
      expect(messageBody.url).toBe('https://example.com/');
      expect(messageBody.options.width).toBe(1920);
      expect(messageBody.options.format).toBe('png');
      expect(messageBody.timestamp).toBeDefined();
    });

    test('should handle SQS errors gracefully', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).rejects(new Error('SQS service unavailable'));

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Internal server error');
    });
  });

  describe('Response format', () => {
    test('should return correct success response format', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).resolves({ MessageId: 'msg-123' });

      const result = await handler(event);

      expect(result.statusCode).toBe(202);
      const body = JSON.parse(result.body);

      expect(body).toEqual({
        success: true,
        jobId: 'test-request-123',
        status: 'pending',
        message: 'Screenshot job created successfully',
        statusUrl: '/api/status/test-request-123',
        timestamp: expect.any(String)
      });

      // Verify timestamp is a valid ISO string
      expect(new Date(body.timestamp).toISOString()).toBe(body.timestamp);
    });

    test('should include proper CORS headers', async () => {
      const event = {
        body: JSON.stringify({
          url: 'https://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).resolves({ MessageId: 'msg-123' });

      const result = await handler(event);

      expect(result.headers).toEqual({
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
      });
    });
  });

  describe('Error handling', () => {
    test('should handle unexpected errors gracefully', async () => {
      // Mock a scenario where parsing succeeds but validation throws
      const event = {
        body: JSON.stringify({
          url: 'https://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      // Force an error by mocking URL constructor to throw
      const originalURL = global.URL;
      global.URL = jest.fn(() => {
        throw new Error('Unexpected error');
      });

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.error).toBe('Internal server error');

      // Restore original URL constructor
      global.URL = originalURL;
    });

    test('should include error details in development mode', async () => {
      process.env.NODE_ENV = 'development';

      const event = {
        body: JSON.stringify({
          url: 'https://example.com'
        }),
        requestContext: { requestId: 'test-request-123' }
      };

      sqsMock.on(SendMessageCommand).rejects(new Error('Specific SQS error'));

      const result = await handler(event);

      expect(result.statusCode).toBe(500);
      const body = JSON.parse(result.body);
      expect(body.success).toBe(false);
      expect(body.details).toBe('Specific SQS error');
    });
  });
});
