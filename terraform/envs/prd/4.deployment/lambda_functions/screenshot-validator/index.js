const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");

const sqsClient = new SQSClient({ region: process.env.AWS_REGION });

// Validation functions (copied from your validator.js)
const validator = {
  validateUrl: (url) => {
    if (!url || typeof url !== "string") {
      return { isValid: false, error: "URL must be a non-empty string" };
    }

    if (url.length > 2048) {
      return { isValid: false, error: "URL too long (max 2048 characters)" };
    }

    try {
      const parsedUrl = new URL(url);

      if (!["http:", "https:"].includes(parsedUrl.protocol)) {
        return { isValid: false, error: "URL must use HTTP or HTTPS protocol" };
      }

      if (!parsedUrl.hostname) {
        return { isValid: false, error: "URL must have a valid hostname" };
      }

      // Validate hostname format (must contain at least one dot for TLD)
      if (!parsedUrl.hostname.includes('.') || parsedUrl.hostname.length < 3) {
        return { isValid: false, error: "URL must have a valid domain name with TLD" };
      }

      // Prevent localhost/private IP access in production
      if (process.env.NODE_ENV === "production") {
        const hostname = parsedUrl.hostname.toLowerCase();
        
        // Block localhost variants
        const blockedHostnames = ["localhost", "127.0.0.1", "0.0.0.0", "::1"];
        if (blockedHostnames.includes(hostname)) {
          return {
            isValid: false,
            error: "URL cannot be localhost or private IP",
          };
        }

        // Block cloud metadata services
        const metadataHosts = [
          "169.254.169.254",           // AWS/Azure/GCP metadata
          "metadata.google.internal",   // GCP metadata
          "metadata",                   // Generic metadata
        ];
        if (metadataHosts.includes(hostname)) {
          return { isValid: false, error: "URL cannot access cloud metadata services" };
        }

        // Block private IP ranges (IPv4)
        if (
          hostname.match(/^10\./) ||                           // 10.0.0.0/8
          hostname.match(/^192\.168\./) ||                     // 192.168.0.0/16
          hostname.match(/^172\.(1[6-9]|2\d|3[01])\./) ||     // 172.16.0.0/12
          hostname.match(/^169\.254\./) ||                     // 169.254.0.0/16 (link-local)
          hostname.match(/^127\./)                             // 127.0.0.0/8 (loopback)
        ) {
          return { isValid: false, error: "URL cannot be private IP address" };
        }

        // Block IPv6 private/local addresses
        if (
          hostname.match(/^::1$/) ||                          // IPv6 localhost
          hostname.match(/^fe80:/i) ||                        // IPv6 link-local
          hostname.match(/^fc00:/i) ||                        // IPv6 unique local
          hostname.match(/^fd00:/i)                           // IPv6 unique local
        ) {
          return { isValid: false, error: "URL cannot be private IPv6 address" };
        }

        // Block DNS rebinding attacks (domains resolving to private IPs)
        const dnsRebindingPatterns = [
          /\.xip\.io$/,           // xip.io service
          /\.nip\.io$/,           // nip.io service  
          /\.sslip\.io$/,         // sslip.io service
          /^localhost\./,         // localhost.domain
        ];
        if (dnsRebindingPatterns.some(pattern => pattern.test(hostname))) {
          return { isValid: false, error: "URL cannot use DNS rebinding services" };
        }

        // Block integer/encoded IP addresses
        if (hostname.match(/^\d{8,10}$/) ||                   // Decimal IP
            hostname.match(/^0x[0-9a-f]{8}$/i) ||            // Hex IP
            hostname.match(/^0[0-7]+$/)) {                    // Octal IP
          return { isValid: false, error: "URL cannot use encoded IP addresses" };
        }
      }

      return { isValid: true, url: parsedUrl };
    } catch (error) {
      return { isValid: false, error: "Invalid URL format" };
    }
  },

  validateScreenshotOptions: (options) => {
    if (!options || typeof options !== "object") {
      return { isValid: true, options: {} };
    }

    const validatedOptions = {};
    const errors = [];

    // Width validation
    if (options.width !== undefined) {
      const width = parseInt(options.width);
      if (isNaN(width) || width < 320 || width > 4096) {
        errors.push("Width must be between 320 and 4096 pixels");
      } else {
        validatedOptions.width = width;
      }
    }

    // Height validation
    if (options.height !== undefined) {
      const height = parseInt(options.height);
      if (isNaN(height) || height < 240 || height > 4096) {
        errors.push("Height must be between 240 and 4096 pixels");
      } else {
        validatedOptions.height = height;
      }
    }

    // Format validation
    if (options.format !== undefined) {
      const validFormats = ["png", "jpeg", "jpg", "webp"];
      if (!validFormats.includes(options.format.toLowerCase())) {
        errors.push("Format must be one of: png, jpeg, jpg, webp");
      } else {
        validatedOptions.format = options.format.toLowerCase();
      }
    }

    // Quality validation
    if (options.quality !== undefined) {
      const quality = parseInt(options.quality);
      if (isNaN(quality) || quality < 1 || quality > 100) {
        errors.push("Quality must be between 1 and 100");
      } else {
        validatedOptions.quality = quality;
      }
    }

    // Full page validation
    if (options.fullPage !== undefined) {
      validatedOptions.fullPage = Boolean(options.fullPage);
    }

    // Timeout validation
    if (options.timeout !== undefined) {
      const timeout = parseInt(options.timeout);
      if (isNaN(timeout) || timeout < 1000 || timeout > 60000) {
        errors.push("Timeout must be between 1000 and 60000 milliseconds");
      } else {
        validatedOptions.timeout = timeout;
      }
    }

    // Wait for network idle validation
    if (options.waitForNetworkIdle !== undefined) {
      validatedOptions.waitForNetworkIdle = Boolean(options.waitForNetworkIdle);
    }

    if (errors.length > 0) {
      return { isValid: false, errors };
    }

    return { isValid: true, options: validatedOptions };
  },
};

exports.handler = async (event) => {
  try {
    console.log("Received event:", JSON.stringify(event, null, 2));

    // Check if body exists
    if (!event.body) {
      console.error("Request body is null or undefined");
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
          "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        body: JSON.stringify({
          success: false,
          error: "Request body is required",
          debug: {
            bodyReceived: event.body,
            eventKeys: Object.keys(event),
            isBase64Encoded: event.isBase64Encoded,
          },
        }),
      };
    }

    // Parse request body
    let body;
    try {
      body = JSON.parse(event.body);
    } catch (parseError) {
      console.error("Failed to parse request body:", parseError);
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
          "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        body: JSON.stringify({
          success: false,
          error: "Invalid JSON in request body",
          debug: {
            rawBody: event.body,
            parseError: parseError.message,
          },
        }),
      };
    }

    const { url, options = {} } = body;

    // Validate URL
    const urlValidation = validator.validateUrl(url);
    if (!urlValidation.isValid) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
          "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        body: JSON.stringify({
          success: false,
          error: urlValidation.error,
        }),
      };
    }

    // Validate options
    const optionsValidation = validator.validateScreenshotOptions(options);
    if (!optionsValidation.isValid) {
      return {
        statusCode: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers":
            "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
          "Access-Control-Allow-Methods": "POST,OPTIONS",
        },
        body: JSON.stringify({
          success: false,
          error: "Invalid screenshot options",
          details: optionsValidation.errors,
        }),
      };
    }

    // Create validated message
    const message = {
      jobId: event.requestContext.requestId,
      url: urlValidation.url.href,
      options: optionsValidation.options,
      timestamp: new Date().toISOString(),
    };

    // Send to SQS
    const command = new SendMessageCommand({
      QueueUrl: process.env.SQS_QUEUE_URL,
      MessageBody: JSON.stringify(message),
      MessageAttributes: {
        MessageType: {
          DataType: "String",
          StringValue: "ScreenshotRequest",
        },
        Timestamp: {
          DataType: "String",
          StringValue: new Date().toISOString(),
        },
        RequestId: {
          DataType: "String",
          StringValue: event.requestContext.requestId,
        },
      },
    });

    await sqsClient.send(command);

    // Return success response
    return {
      statusCode: 202,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
      },
      body: JSON.stringify({
        success: true,
        jobId: event.requestContext.requestId,
        status: "pending",
        message: "Screenshot job created successfully",
        statusUrl: `/api/status/${event.requestContext.requestId}`,
        timestamp: new Date().toISOString(),
      }),
    };
  } catch (error) {
    console.error("Error processing request:", error);

    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
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
