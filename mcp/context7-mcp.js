module.exports = {
  id: "context7",
  description: "Query Context7 RAG engine",
  methods: {
    query: async ({ prompt }) => {
      const res = await fetch("http://localhost:7080/query", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ input: prompt }),
      });
      return await res.json();
    },
  }
};