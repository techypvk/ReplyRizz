const axios = require('axios');

const apiKey = 'AIzaSyDyHDcYQuSpi8-GtYXrbtqeSFefrpDqKNk';
const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

const data = {
    contents: [{ parts: [{ text: 'Say hello' }] }],
    generationConfig: {
        responseMimeType: 'application/json',
    },
};

axios.post(url, data)
    .then(response => {
        console.log('Success:', JSON.stringify(response.data, null, 2));
    })
    .catch(error => {
        console.error('Error:', error.response ? JSON.stringify(error.response.data, null, 2) : error.message);
    });
