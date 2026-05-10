// Force public access - bypass JWT verification
// @ts-ignore
const ZYNLEPAY_ENDPOINTS = [
  "https://sandbox.zynlepay.com/v1/payment/process",
  "https://sandbox.zynlepay.com/v1/payment/mobile-money",
  "https://sandbox.zynlepay.com/payment/mobile-money",
  "https://sandbox.zynlepay.com/api/charge",
] as const;
const DEFAULT_CURRENCY = "ZMW";
const DEFAULT_SUCCESS_URL = "https://webhook.site/test";
const DEFAULT_CALLBACK_URL = "https://webhook.site/test";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const supportedMethods = new Set(["airtel", "mtn"]);

type PaymentRequest = {
  phoneNumber?: unknown;
  amount?: unknown;
  paymentMethod?: unknown;
  currency?: unknown;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      405,
      { success: false, message: "Method not allowed. Use POST." },
    );
  }

  const merchantCode = Deno.env.get("ZYNLEPAY_MERCHANT_CODE")?.trim();
  const apiId = Deno.env.get("ZYNLEPAY_API_ID")?.trim();
  const apiKey = Deno.env.get("ZYNLEPAY_API_KEY")?.trim();
  const apiIdHeader =
    Deno.env.get("ZYNLEPAY_API_ID_HEADER")?.trim() || "X-API-ID";
  const apiKeyHeader =
    Deno.env.get("ZYNLEPAY_API_KEY_HEADER")?.trim() || "X-API-KEY";

  if (!merchantCode || !apiId || !apiKey) {
    return jsonResponse(
      500,
      {
        success: false,
        message: "ZynlePay sandbox credentials are not configured.",
      },
    );
  }

  let payload: PaymentRequest;
  try {
    payload = await request.json();
  } catch (_) {
    return jsonResponse(
      400,
      { success: false, message: "Invalid JSON request body." },
    );
  }

  const validation = validatePayload(payload);
  if (!validation.valid) {
    return jsonResponse(
      400,
      { success: false, message: validation.message },
    );
  }

  const { phoneNumber, amount, paymentMethod, currency } = validation;
  const providerPayload = {
    merchant_code: merchantCode,
    amount,
    currency,
    phone_number: phoneNumber,
    payment_method: paymentMethod,
    success_url: DEFAULT_SUCCESS_URL,
    callback_url: DEFAULT_CALLBACK_URL,
  };

  try {
    const upstreamResult = await submitToZynlePay({
      apiId,
      apiKey,
      apiIdHeader,
      apiKeyHeader,
      payload: providerPayload,
    });
    const upstreamResponse = upstreamResult.response;
    const upstreamBody = upstreamResult.body;
    const upstreamMessage = getResponseMessage(upstreamBody);

    if (!upstreamResponse.ok) {
      return jsonResponse(
        502,
        {
          success: false,
          message: upstreamMessage || "ZynlePay sandbox request failed.",
          paymentMethod,
          statusCode: upstreamResponse.status,
          endpoint: upstreamResult.endpoint,
          providerResponse: upstreamBody,
        },
      );
    }

    return jsonResponse(
      200,
      {
        success: true,
        message:
          upstreamMessage || "ZynlePay sandbox payment request submitted.",
        paymentMethod,
        statusCode: upstreamResponse.status,
        endpoint: upstreamResult.endpoint,
        providerResponse: upstreamBody,
      },
    );
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Unable to reach the ZynlePay sandbox.";

    return jsonResponse(
      502,
      {
        success: false,
        message,
        paymentMethod,
        endpoint: ZYNLEPAY_ENDPOINTS[0],
      },
    );
  }
});

function validatePayload(payload: PaymentRequest):
  | {
    valid: true;
    phoneNumber: string;
    amount: number;
    paymentMethod: string;
    currency: string;
  }
  | {
    valid: false;
    message: string;
  } {
  const phoneNumber = typeof payload.phoneNumber === "string"
    ? payload.phoneNumber.trim()
    : "";
  const paymentMethod = typeof payload.paymentMethod === "string"
    ? payload.paymentMethod.trim().toLowerCase()
    : "";
  const currency = typeof payload.currency === "string" &&
      payload.currency.trim().length > 0
    ? payload.currency.trim().toUpperCase()
    : DEFAULT_CURRENCY;
  const amount = typeof payload.amount === "number"
    ? payload.amount
    : typeof payload.amount === "string"
    ? Number(payload.amount)
    : Number.NaN;

  if (!phoneNumber) {
    return { valid: false, message: "phoneNumber is required." };
  }

  if (!Number.isFinite(amount) || amount <= 0) {
    return { valid: false, message: "amount must be greater than 0." };
  }

  if (!supportedMethods.has(paymentMethod)) {
    return {
      valid: false,
      message: "paymentMethod must be either Airtel or MTN.",
    };
  }

  if (!currency) {
    return { valid: false, message: "currency is required." };
  }

  return {
    valid: true,
    phoneNumber,
    amount,
    paymentMethod,
    currency,
  };
}

async function parseResponseBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
}

async function submitToZynlePay(options: {
  apiId: string;
  apiKey: string;
  apiIdHeader: string;
  apiKeyHeader: string;
  payload: Record<string, unknown>;
}): Promise<{ endpoint: string; response: Response; body: unknown }> {
  let lastResult: { endpoint: string; response: Response; body: unknown } | null = null;

  for (const endpoint of ZYNLEPAY_ENDPOINTS) {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        [options.apiIdHeader]: options.apiId,
        [options.apiKeyHeader]: options.apiKey,
        "x-api-id": options.apiId,
        "x-api-key": options.apiKey,
      },
      body: JSON.stringify(options.payload),
    });

    const body = await parseResponseBody(response);
    lastResult = { endpoint, response, body };

    if (response.status !== 404) {
      return lastResult;
    }
  }

  if (lastResult != null) {
    return lastResult;
  }

  throw new Error("No ZynlePay endpoints were available.");
}

function getResponseMessage(body: unknown): string | null {
  if (body && typeof body === "object") {
    const message = Reflect.get(body, "message");
    if (typeof message === "string") {
      const trimmedMessage = message.trim();
      if (trimmedMessage.length > 0) {
        return trimmedMessage;
      }
    }

    const error = Reflect.get(body, "error");
    if (typeof error === "string") {
      const trimmedError = error.trim();
      if (trimmedError.length > 0) {
        return trimmedError;
      }
    }
  }

  return null;
}

function jsonResponse(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}
