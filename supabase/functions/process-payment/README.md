`process-payment` now targets the ZynlePay sandbox endpoint list in this order:

- `https://sandbox.zynlepay.com/v1/payment/process`
- `https://sandbox.zynlepay.com/v1/payment/mobile-money`
- `https://sandbox.zynlepay.com/payment/mobile-money`
- `https://sandbox.zynlepay.com/api/charge`

Store these Supabase secrets before deploying:

- `ZYNLEPAY_MERCHANT_CODE`
- `ZYNLEPAY_API_ID`
- `ZYNLEPAY_API_KEY`

Optional secrets if your provider uses different auth header names:

- `ZYNLEPAY_API_ID_HEADER`
- `ZYNLEPAY_API_KEY_HEADER`

Example deployment flow:

```bash
supabase secrets set ZYNLEPAY_MERCHANT_CODE=... ZYNLEPAY_API_ID=... ZYNLEPAY_API_KEY=...
supabase functions deploy process-payment
```

Request body expected by the function:

```json
{
  "phoneNumber": "26097XXXXXXX",
  "amount": 50,
  "paymentMethod": "Airtel",
  "currency": "ZMW"
}
```

The function normalizes `paymentMethod` to `airtel` or `mtn`, defaults `currency` to `ZMW`, sends the ZynlePay sandbox payload with `merchant_code`, `phone_number`, `success_url`, and `callback_url`, sends credentials in `x-api-id` and `x-api-key` headers, and retries the alternative endpoints only when ZynlePay returns `404 Not Found`.
