# Keys to Better Prompts

Read this BEFORE writing any prompt. Every prompt must follow these 8 keys.

---

### 1. Clarity & Specificity (The #1 key)
Vague prompts = vague results. Add who, what, when, where, why, how, constraints, and desired length.

Bad: "Tell me about history."
Good: "Summarize the key causes, major events, and long-term consequences of the fall of the Roman Empire in 3–4 paragraphs, aimed at a high-school student."

### 2. Give the AI a Role
Tell the model who it is before asking it to do anything.
"You are a world-class [role] with 20+ years of experience…"

### 3. Use Few-Shot Examples
Give 1–3 examples of the exact style, format, or quality you want. Especially powerful for tone, structure, or creative tasks.

### 4. Force Step-by-Step Reasoning (Chain-of-Thought)
Add one of these:
- "Think step by step."
- "Explain your reasoning before giving the final answer."
- "Use chain-of-thought reasoning."

### 5. Specify Exact Output Format
Never leave format to chance.
- "Respond in a numbered list"
- "Output only a JSON object with keys: title, summary, keywords"
- "Use markdown with H2 headings and bullet points"
- "Give me a table with columns X, Y, Z"

### 6. Set Constraints & Guardrails
- Tone: "Use a witty, slightly sarcastic tone"
- Length: "Maximum 200 words" / "At least 800 words"
- Style: "No jargon" / "Advanced academic tone"
- Forbidden: "Do not use clichés" / "Avoid corporate speak"

### 7. Structure Long Prompts Clearly
Use delimiters and sections so the AI doesn't get lost:
```
Task: [what you want]
Context: [background info]
Requirements: [list]
Examples: [few-shot]
Output format: [exact format]
```

### 8. Iterate Ruthlessly
The best prompt almost never happens on the first try. After the first response, refine:
- "Make it more concise and add real-world examples."
- "Rewrite this in the style of [author]."
- "Improve the reasoning in step 3."

---

## Quick Template

```
You are a world-class [role].
Task: [clear goal]
Context: [relevant background]
Requirements: [list of must-haves]
Output format: [exact format]
Think step by step.
```
