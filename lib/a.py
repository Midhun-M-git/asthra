import os
import requests

url = "https://openrouter.ai/api/v1/chat/completions"
headers = {
    "Authorization": f"Bearer {os.environ.get('OPENROUTER_API_KEY')}",
    "HTTP-Referer": "https://yourapp.com",  # set to your app/localhost
    "X-Title": "ASTHRA",                    # optional title
    "Content-Type": "application/json",
}

payload = {
    "model": "amazon/nova-2-lite-v1",  # or amazon/nova-2-lite-v1:free if available
    "messages": [
        {"role": "user", "content": "If you built the world's tallest skyscraper, what would you name it?"}
    ],
    "stream": False  # set True only if you handle streaming chunks
}

resp = requests.post(url, headers=headers, json=payload, timeout=60)
print(resp.status_code, resp.text)
