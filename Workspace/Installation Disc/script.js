document.addEventListener('DOMContentLoaded', () => {
    const copyBtn = document.getElementById('copy-btn');
    const textArea = document.getElementById('prompt-text');
    const feedbackMsg = document.getElementById('copy-feedback');

    copyBtn.addEventListener('click', async () => {
        try {
            await navigator.clipboard.writeText(textArea.value);
            
            // Show feedback
            feedbackMsg.classList.add('show');
            
            // Add a little pop effect to the button
            copyBtn.style.transform = 'scale(0.95)';
            setTimeout(() => {
                copyBtn.style.transform = '';
            }, 100);
            
            // Hide feedback after 2 seconds
            setTimeout(() => {
                feedbackMsg.classList.remove('show');
            }, 2000);
        } catch (err) {
            console.error('Failed to copy text: ', err);
            // Fallback for older browsers
            textArea.select();
            document.execCommand('copy');
            feedbackMsg.textContent = 'Copied!';
            feedbackMsg.classList.add('show');
            setTimeout(() => {
                feedbackMsg.classList.remove('show');
            }, 2000);
        }
    });

    // Optional: Select text on focus for easy manual copying
    textArea.addEventListener('focus', () => {
        textArea.select();
    });
});
