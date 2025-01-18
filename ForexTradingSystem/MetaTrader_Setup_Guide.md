# MetaTrader API Integration Setup Guide

## 1. Obtaining Your MetaTrader API Key

1. Log in to your MetaTrader account through your broker's website
2. Navigate to the API Management section (location varies by broker)
3. Generate a new API key with the following permissions:
   - Trading operations
   - Account information access
   - MQL execution
4. Copy the generated API key (a long string of random characters)

## 2. Configuring the .env File

1. Open the `.env` file in your project
2. Update the following values:

```env
MT_API_URL=https://api.metatrader.com/v1
MT_API_KEY=your_generated_api_key_here
MT_ACCOUNT_ID=your_account_number
```

3. Save the file

## 3. Testing the Connection

1. Run the following command to test the connection:

```bash
python3 -c "from modules.mt_execution import MTExecution; mt = MTExecution('https://api.metatrader.com/v1', 'your_api_key'); print(mt.get_account_info())"
```

2. If successful, you should see your account information printed
3. If you receive an error, verify:
   - Your API key is correct
   - Your account has API access enabled
   - The API URL matches your broker's endpoint

## 4. Using MQL Features

Once connected, you can:
- Execute custom MQL code
- Calculate technical indicators
- Backtest strategies
- Automate trading operations

Refer to the MQL documentation for advanced usage: https://www.mql5.com/en/docs
