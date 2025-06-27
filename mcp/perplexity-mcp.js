module.exports = {
  id: "perplexity",
  description: "Query Perplexity.ai",
  methods: {
    ask: async ({ query }) => {
      const res = await fetch("https://api.perplexity.ai/search", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer YOUR_PERPLEXITY_API_KEY"
        },
        body: JSON.stringify({ query })
      });
      return await res.json();
    }
  }
};