async function generateSdfViaPuter(promptText) {
  if (typeof puter === 'undefined') {
    throw new Error('Puter.js is not loaded');
  }

  try {
    const response = await puter.ai.chat(promptText, {
      model: 'google/gemini-3.1-pro-preview',
    });

    // Handle different response structures based on the model
    if (typeof response === 'string') {
      return response;
    } else if (response && response.message && response.message.content) {
      const content = response.message.content;
      if (typeof content === 'string') {
        return content;
      } else if (Array.isArray(content) && content.length > 0 && content[0].text) {
        return content[0].text;
      }
    }
    
    // Fallback: stringify the raw response if unknown format
    return JSON.stringify(response);
  } catch (err) {
    console.error('Puter API error:', err);
    throw err;
  }
}
