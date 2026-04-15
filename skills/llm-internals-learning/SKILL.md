```markdown
---
name: llm-internals-learning
description: Skill for understanding and implementing LLM internals concepts from tokenization to attention mechanisms to inference optimization
triggers:
  - "explain how attention works in transformers"
  - "implement KV cache for LLM inference"
  - "show me how tokenization works in LLMs"
  - "how does flash attention work"
  - "implement causal masking in attention"
  - "explain mixture of experts architecture"
  - "how does byte pair encoding work"
  - "implement transformer attention from scratch"
---

# LLM Internals Learning Guide

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A structured, step-by-step educational resource for learning how Large Language Models work internally — from tokenization and embeddings through attention mechanisms, transformer architecture, and inference optimization techniques like KV Cache and Flash Attention.

---

## What This Project Covers

| Topic | Concept |
|---|---|
| Tokenization | BPE, subword splitting, vocabulary |
| Attention | Q, K, V matrices, scaled dot-product |
| Masking | Causal masking, attention masks |
| Architecture | Transformer encoder/decoder, FFN, MoE |
| Optimization | KV Cache, Paged Attention, Flash Attention |
| Training | Backpropagation, gradient descent |

---

## Core Concept Implementations

### 1. Byte Pair Encoding (BPE) Tokenization

```python
from collections import defaultdict

def get_vocab(text: str) -> dict:
    """Build initial character-level vocabulary with end-of-word marker."""
    vocab = defaultdict(int)
    for word in text.strip().split():
        chars = " ".join(list(word)) + " </w>"
        vocab[chars] += 1
    return dict(vocab)

def get_pairs(vocab: dict) -> dict:
    """Count all adjacent symbol pairs in the vocabulary."""
    pairs = defaultdict(int)
    for word, freq in vocab.items():
        symbols = word.split()
        for i in range(len(symbols) - 1):
            pairs[(symbols[i], symbols[i + 1])] += freq
    return dict(pairs)

def merge_vocab(pair: tuple, vocab: dict) -> dict:
    """Merge the most frequent pair throughout the vocabulary."""
    new_vocab = {}
    bigram = " ".join(pair)
    replacement = "".join(pair)
    for word in vocab:
        new_word = word.replace(bigram, replacement)
        new_vocab[new_word] = vocab[word]
    return new_vocab

def run_bpe(text: str, num_merges: int = 10) -> list:
    """Run BPE algorithm for num_merges iterations."""
    vocab = get_vocab(text)
    merges = []

    for _ in range(num_merges):
        pairs = get_pairs(vocab)
        if not pairs:
            break
        best_pair = max(pairs, key=pairs.get)
        vocab = merge_vocab(best_pair, vocab)
        merges.append(best_pair)
        print(f"Merged: {best_pair} -> {''.join(best_pair)}")

    return merges

# Example usage
text = "low lower lowest newer newest"
merges = run_bpe(text, num_merges=8)
```

---

### 2. Scaled Dot-Product Attention (Q, K, V)

```python
import numpy as np

def scaled_dot_product_attention(Q: np.ndarray, K: np.ndarray, V: np.ndarray,
                                  mask: np.ndarray = None) -> tuple:
    """
    Compute scaled dot-product attention.

    Args:
        Q: Query matrix  (seq_len, d_k)
        K: Key matrix    (seq_len, d_k)
        V: Value matrix  (seq_len, d_v)
        mask: Optional causal mask (seq_len, seq_len)

    Returns:
        output: Attention-weighted values
        weights: Attention weight matrix
    """
    d_k = Q.shape[-1]

    # Step 1: Compute raw attention scores
    scores = Q @ K.T  # (seq_len, seq_len)

    # Step 2: Scale by sqrt(d_k) to stabilize gradients
    scores = scores / np.sqrt(d_k)

    # Step 3: Apply causal mask (if provided)
    if mask is not None:
        scores = np.where(mask == 0, -1e9, scores)

    # Step 4: Softmax to get attention weights
    # Subtract max for numerical stability
    scores_shifted = scores - scores.max(axis=-1, keepdims=True)
    exp_scores = np.exp(scores_shifted)
    weights = exp_scores / exp_scores.sum(axis=-1, keepdims=True)

    # Step 5: Weighted sum of values
    output = weights @ V  # (seq_len, d_v)

    return output, weights


# Example: 3-token sequence, d_k=4, d_v=4
np.random.seed(42)
seq_len, d_k, d_v = 3, 4, 4

# Learnable projection matrices
W_Q = np.random.randn(d_k, d_k)
W_K = np.random.randn(d_k, d_k)
W_V = np.random.randn(d_k, d_v)

# Token embeddings
X = np.random.randn(seq_len, d_k)

Q = X @ W_Q
K = X @ W_K
V = X @ W_V

output, weights = scaled_dot_product_attention(Q, K, V)
print("Attention weights:\n", np.round(weights, 4))
print("Output shape:", output.shape)
```

---

### 3. Causal Masking

```python
import numpy as np

def create_causal_mask(seq_len: int) -> np.ndarray:
    """
    Create a causal (autoregressive) mask.
    Position [i,j] = 1 if token i can attend to token j (j <= i).
    Position [i,j] = 0 if token i cannot attend to token j (j > i).
    """
    mask = np.tril(np.ones((seq_len, seq_len)))
    return mask

def masked_attention(Q, K, V, seq_len):
    mask = create_causal_mask(seq_len)
    output, weights = scaled_dot_product_attention(Q, K, V, mask=mask)
    return output, weights

# Visualize the causal mask for a 5-token sequence
seq_len = 5
mask = create_causal_mask(seq_len)
print("Causal Mask (1=can attend, 0=blocked):")
print(mask.astype(int))

# Token 0 can only see itself
# Token 4 can see all previous tokens
```

---

### 4. Multi-Head Attention

```python
import numpy as np

class MultiHeadAttention:
    def __init__(self, d_model: int, num_heads: int):
        assert d_model % num_heads == 0, "d_model must be divisible by num_heads"
        self.d_model = d_model
        self.num_heads = num_heads
        self.d_k = d_model // num_heads

        # Initialize projection weights
        np.random.seed(0)
        self.W_Q = np.random.randn(d_model, d_model) * 0.01
        self.W_K = np.random.randn(d_model, d_model) * 0.01
        self.W_V = np.random.randn(d_model, d_model) * 0.01
        self.W_O = np.random.randn(d_model, d_model) * 0.01

    def split_heads(self, x: np.ndarray) -> np.ndarray:
        """Split last dimension into (num_heads, d_k)."""
        seq_len = x.shape[0]
        x = x.reshape(seq_len, self.num_heads, self.d_k)
        return x.transpose(1, 0, 2)  # (num_heads, seq_len, d_k)

    def forward(self, X: np.ndarray, mask: np.ndarray = None) -> np.ndarray:
        seq_len = X.shape[0]

        # Project to Q, K, V
        Q = X @ self.W_Q  # (seq_len, d_model)
        K = X @ self.W_K
        V = X @ self.W_V

        # Split into heads
        Q = self.split_heads(Q)  # (num_heads, seq_len, d_k)
        K = self.split_heads(K)
        V = self.split_heads(V)

        # Attention per head
        head_outputs = []
        for h in range(self.num_heads):
            out, _ = scaled_dot_product_attention(Q[h], K[h], V[h], mask)
            head_outputs.append(out)

        # Concatenate heads
        concat = np.concatenate(head_outputs, axis=-1)  # (seq_len, d_model)

        # Final projection
        output = concat @ self.W_O
        return output


# Usage
d_model, num_heads, seq_len = 512, 8, 10
mha = MultiHeadAttention(d_model=d_model, num_heads=num_heads)
X = np.random.randn(seq_len, d_model)
mask = create_causal_mask(seq_len)
output = mha.forward(X, mask=mask)
print("Multi-head attention output shape:", output.shape)
```

---

### 5. KV Cache Implementation

```python
import numpy as np
from typing import Optional

class KVCache:
    """
    Key-Value cache for autoregressive LLM inference.
    Avoids recomputing K and V for previously seen tokens.
    """
    def __init__(self, max_seq_len: int, d_k: int, num_heads: int):
        self.max_seq_len = max_seq_len
        self.d_k = d_k
        self.num_heads = num_heads
        self.current_len = 0

        # Pre-allocate cache buffers
        self.k_cache = np.zeros((num_heads, max_seq_len, d_k))
        self.v_cache = np.zeros((num_heads, max_seq_len, d_k))

    def update(self, new_k: np.ndarray, new_v: np.ndarray) -> tuple:
        """
        Append new K, V vectors and return full cached K, V.

        Args:
            new_k: (num_heads, 1, d_k) - key for new token
            new_v: (num_heads, 1, d_k) - value for new token

        Returns:
            Full K and V including all past tokens
        """
        pos = self.current_len
        self.k_cache[:, pos:pos+1, :] = new_k
        self.v_cache[:, pos:pos+1, :] = new_v
        self.current_len += 1

        return (
            self.k_cache[:, :self.current_len, :],
            self.v_cache[:, :self.current_len, :]
        )

    def reset(self):
        self.current_len = 0
        self.k_cache[:] = 0
        self.v_cache[:] = 0


def inference_with_kv_cache(tokens: list, d_model: int = 64, num_heads: int = 4):
    """Demonstrate token-by-token generation with KV cache."""
    d_k = d_model // num_heads
    cache = KVCache(max_seq_len=512, d_k=d_k, num_heads=num_heads)

    W_K = np.random.randn(d_model, d_model) * 0.01
    W_V = np.random.randn(d_model, d_model) * 0.01
    W_Q = np.random.randn(d_model, d_model) * 0.01

    print(f"Generating {len(tokens)} tokens with KV Cache:\n")

    for step, token_embedding in enumerate(tokens):
        token_embedding = token_embedding.reshape(1, -1)  # (1, d_model)

        # Only compute Q, K, V for the NEW token
        q = (token_embedding @ W_Q).reshape(num_heads, 1, d_k)
        k = (token_embedding @ W_K).reshape(num_heads, 1, d_k)
        v = (token_embedding @ W_V).reshape(num_heads, 1, d_k)

        # Get full K, V from cache
        full_k, full_v = cache.update(k, v)

        print(f"Step {step+1}: Query attends to {cache.current_len} token(s)")
        # Attention: new query attends to ALL past keys/values
        # Without cache: would recompute K, V for all past tokens each step


# Simulate 5-token generation
d_model = 64
token_embeddings = [np.random.randn(d_model) for _ in range(5)]
inference_with_kv_cache(token_embeddings, d_model=d_model, num_heads=4)
```

---

### 6. Feed-Forward Network (FFN) in Transformer

```python
import numpy as np

def relu(x: np.ndarray) -> np.ndarray:
    return np.maximum(0, x)

class FeedForwardNetwork:
    """
    Position-wise Feed-Forward Network used in each Transformer layer.
    FFN(x) = max(0, xW1 + b1)W2 + b2

    Expands d_model -> d_ff (typically 4x), then contracts back.
    """
    def __init__(self, d_model: int, d_ff: int):
        self.W1 = np.random.randn(d_model, d_ff) * np.sqrt(2.0 / d_model)
        self.b1 = np.zeros(d_ff)
        self.W2 = np.random.randn(d_ff, d_model) * np.sqrt(2.0 / d_ff)
        self.b2 = np.zeros(d_model)

    def forward(self, x: np.ndarray) -> np.ndarray:
        """
        x: (seq_len, d_model)
        Returns: (seq_len, d_model)
        """
        # Expand: d_model -> d_ff
        hidden = relu(x @ self.W1 + self.b1)  # (seq_len, d_ff)
        # Contract: d_ff -> d_model
        output = hidden @ self.W2 + self.b2    # (seq_len, d_model)
        return output


# Standard GPT-style: d_model=768, d_ff=3072 (4x expansion)
d_model, d_ff, seq_len = 768, 3072, 10
ffn = FeedForwardNetwork(d_model=d_model, d_ff=d_ff)

x = np.random.randn(seq_len, d_model)
out = ffn.forward(x)
print(f"FFN input:  {x.shape}")
print(f"FFN output: {out.shape}")
print(f"Parameter count: W1={ffn.W1.size:,} + W2={ffn.W2.size:,} = {ffn.W1.size + ffn.W2.size:,}")
```

---

### 7. Backpropagation (Numeric Example)

```python
import numpy as np

def sigmoid(x):
    return 1 / (1 + np.exp(-x))

def sigmoid_derivative(x):
    s = sigmoid(x)
    return s * (1 - s)

def mse_loss(y_pred, y_true):
    return 0.5 * np.mean((y_pred - y_true) ** 2)

class SimpleNeuralNet:
    """
    2-layer neural network demonstrating backpropagation step by step.
    Input(2) -> Hidden(3) -> Output(1)
    """
    def __init__(self, lr: float = 0.1):
        np.random.seed(42)
        self.W1 = np.random.randn(2, 3) * 0.5
        self.b1 = np.zeros((1, 3))
        self.W2 = np.random.randn(3, 1) * 0.5
        self.b2 = np.zeros((1, 1))
        self.lr = lr

    def forward(self, X):
        self.X = X
        self.z1 = X @ self.W1 + self.b1
        self.a1 = sigmoid(self.z1)
        self.z2 = self.a1 @ self.W2 + self.b2
        self.a2 = sigmoid(self.z2)
        return self.a2

    def backward(self, y_true):
        n = y_true.shape[0]

        # Output layer gradients
        dL_da2 = (self.a2 - y_true) / n
        da2_dz2 = sigmoid_derivative(self.z2)
        dL_dz2 = dL_da2 * da2_dz2

        dL_dW2 = self.a1.T @ dL_dz2
        dL_db2 = dL_dz2.sum(axis=0, keepdims=True)

        # Hidden layer gradients
        dL_da1 = dL_dz2 @ self.W2.T
        da1_dz1 = sigmoid_derivative(self.z1)
        dL_dz1 = dL_da1 * da1_dz1

        dL_dW1 = self.X.T @ dL_dz1
        dL_db1 = dL_dz1.sum(axis=0, keepdims=True)

        # Gradient descent update
        self.W2 -= self.lr * dL_dW2
        self.b2 -= self.lr * dL_db2
        self.W1 -= self.lr * dL_dW1
        self.b1 -= self.lr * dL_db1

    def train(self, X, y, epochs=1000):
        for epoch in range(epochs):
            y_pred = self.forward(X)
            loss = mse_loss(y_pred, y)
            self.backward(y)
            if epoch % 200 == 0:
                print(f"Epoch {epoch:4d} | Loss: {loss:.6f}")


# XOR problem
X = np.array([[0,0],[0,1],[1,0],[1,1]], dtype=float)
y = np.array([[0],[1],[1],[0]], dtype=float)

net = SimpleNeuralNet(lr=0.5)
net.train(X, y, epochs=1000)
print("\nPredictions after training:")
print(np.round(net.forward(X), 3))
```

---

### 8. Mixture of Experts (MoE) Router

```python
import numpy as np

def softmax(x: np.ndarray, axis: int = -1) -> np.ndarray:
    e = np.exp(x - x.max(axis=axis, keepdims=True))
    return e / e.sum(axis=axis, keepdims=True)

class MixtureOfExperts:
    """
    Sparse MoE layer: routes each token to top-K experts.
    Each 'expert' is a simple FFN.
    """
    def __init__(self, d_model: int, num_experts: int, top_k: int, d_ff: int = None):
        self.d_model = d_model
        self.num_experts = num_experts
        self.top_k = top_k
        self.d_ff = d_ff or d_model * 4

        # Router (gating network)
        self.W_router = np.random.randn(d_model, num_experts) * 0.01

        # Expert FFNs
        self.experts = [
            {
                "W1": np.random.randn(d_model, self.d_ff) * 0.01,
                "W2": np.random.randn(self.d_ff, d_model) * 0.01,
            }
            for _ in range(num_experts)
        ]

    def route(self, x: np.ndarray) -> tuple:
        """
        Compute top-K expert assignments for each token.

        Args:
            x: (seq_len, d_model)

        Returns:
            top_k_indices: (seq_len, top_k)
            top_k_weights: (seq_len, top_k) - normalized routing weights
        """
        # Router logits
        logits = x @ self.W_router        # (seq_len, num_experts)
        probs = softmax(logits, axis=-1)  # (seq_len, num_experts)

        # Select top-K experts per token
        top_k_indices = np.argsort(probs, axis=-1)[:, -self.top_k:][:, ::-1]
        top_k_weights = np.take_along_axis(probs, top_k_indices, axis=1)

        # Normalize weights across selected experts
        top_k_weights = top_k_weights / top_k_weights.sum(axis=-1, keepdims=True)

        return top_k_indices, top_k_weights

    def forward(self, x: np.ndarray) -> np.ndarray:
        seq_len = x.shape[0]
        top_k_indices, top_k_weights = self.route(x)
        output = np.zeros_like(x)

        for token_idx in range(seq_len):
            for k in range(self.top_k):
                expert_id = top_k_indices[token_idx, k]
                weight = top_k_weights[token_idx, k]
                expert = self.experts[expert_id]

                # Expert FFN computation
                hidden = np.maximum(0, x[token_idx] @ expert["W1"])
                expert_out = hidden @ expert["W2"]
                output[token_idx] += weight * expert_out

        return output

    def print_routing_stats(self, x: np.ndarray):
        indices, weights = self.route(x)
        expert_load = np.zeros(self.num_experts)
        for row in indices:
            for idx in row:
                expert_load[idx] += 1
        print(f"Expert load distribution (tokens per expert):")
        for i, load in enumerate(expert_load):
            bar = "█" * int(load)
            print(f"  Expert {i}: {bar} ({int(load)})")


# Usage: 8 experts, top-2 routing (like Mixtral)
moe = MixtureOfExperts(d_model=64, num_experts=8, top_k=2)
X = np.random.randn(6, 64)   # 6 tokens

output = moe.forward(X)
print(f"MoE output shape: {output.shape}")
print()
moe.print_routing_stats(X)
```

---

## Key Concepts Quick Reference

### The √dₖ Scaling Factor

```python
import numpy as np

# Demonstrate why scaling is needed
np.random.seed(0)
d_k = 64
q = np.random.randn(d_k)
k = np.random.randn(d_k)

dot = np.dot(q, k)
print(f"d_k = {d_k}")
print(f"Dot product: {dot:.2f}")
print(f"Variance grows with d_k: E[dot^2] ≈ {d_k}")

# Without scaling: softmax gets very "peaky" (near one-hot)
scores_unscaled = np.array([dot, dot * 0.8, dot * 0.3])
scores_scaled   = scores_unscaled / np.sqrt(d_k)

def softmax_1d(x):
    e = np.exp(x - x.max())
    return e / e.sum()

print(f"\nWithout scaling: {np.round(softmax_1d(scores_unscaled), 4)}")
print(f"With √dₖ scaling: {np.round(softmax_1d(scores_scaled), 4)}")
# Scaled version has softer distribution — better gradients
```

### Paged Attention (Conceptual)

```python
class PagedKVCache:
    """
    Conceptual implementation of Paged Attention (as used in vLLM).
    Physical KV memory is divided into fixed-size blocks (pages).
    Each sequence gets a logical block table mapping to physical blocks.
    """
    def __init__(self, block_size: int, num_blocks: int, d_k: int, num_heads: int):
        self.block_size = block_size
        self.num_blocks = num_blocks

        # Physical memory pool
        self.physical_k = np.zeros((num_blocks, block_size, num_heads, d_k))
        self.physical_v = np.zeros((num_blocks, block_size, num_heads, d_k))

        # Free block list
        self.free_blocks = list(range(num_blocks))

        # Per-sequence block tables: seq_id -> [physical_block_ids]
        self.block_tables = {}

    def allocate_block(self, seq_id: int):
        """Allocate a new physical block for a sequence."""
        if not self.free_blocks:
            raise MemoryError("KV cache out of memory — no free blocks")
        block_id = self.free_blocks.pop(0)
        if seq_id not in self.block_tables:
            self.block_tables[seq_id] = []
        self.block_tables[seq_id].append(block_id)
        print(f"Seq {seq_id}: allocated physical block {block_id}")
        return block_id

    def free_sequence(self, seq_id: int):
        """Return all blocks for a completed sequence to the free pool."""
        if seq_id in self.block_tables:
            freed = self.block_tables.pop(seq_id)
            self.free_blocks.extend(freed)
            print(f"Seq {seq_id}: freed blocks {freed}, pool size: {len(self.free_blocks)}")

    def stats(self):
        used = self.num_blocks - len(self.free_blocks)
        print(f"Blocks: {used}/{self.num_blocks} used ({100*used/self.num_blocks:.1f}%)")


# Simulate 3 concurrent requests
cache = PagedKVCache(block_size=16, num_blocks=10, d_k=64, num_heads=8)
cache.allocate_block(seq_id=0)
cache.allocate_block(seq_id=0)
cache.allocate_block(seq_id=1)
cache.allocate_block(seq_id=2)
cache.stats()

# Sequence 1 finishes — its blocks return to the pool
cache.free_sequence(seq_id=1)
cache.stats()
```

---

## Learning Path

Follow these concepts in order for best understanding:

```
1. Tokenization → BPE
2. Embeddings → Positional Encoding
3. Attention → Scaled Dot-Product → Multi-Head
4. Causal Masking
5. Feed-Forward Networks
6. Full Transformer Block (Attention + FFN + LayerNorm + Residuals)
7. Backpropagation
8. Inference Optimization:
   ├── KV Cache
   ├── Paged Attention
   └── Flash Attention
9. Architecture Variants:
   ├── Encoder-only (BERT)
   ├── Decoder-only (GPT)
   └── Encoder-Decoder (T5)
10. Mixture of Experts (MoE)
```

---

## Resources in This Project

| Topic | Type | Link |
|---|---|---|
| LLM Overview (LLM, RAG, MCP, Agent) | Video | YouTube |
| Tokenization | Video | YouTube |
| Byte Pair Encoding | Blog | outcomeschool.com |
| Math behind Q, K, V | Blog | outcomeschool.com |
| √dₖ Scaling Factor | Blog | outcomeschool.com |
| Causal Masking | Blog | outcomeschool.com |
| Backpropagation | Blog | outcomeschool.com |
| Transformer Architecture | Blog | outcomeschool.com |
| Feed-Forward Networks | Blog | outcomeschool.com |
| KV Cache | Blog | outcomeschool.com |
| Paged Attention | Blog | outcomeschool.com |
| Flash Attention | Blog | outcomeschool.com |
| Mixture of Experts | Blog | outcomeschool.com |
| Harness Engineering | Blog | outcomeschool.com |

---

## Common Patterns & Gotchas

### Attention Shape Conventions

```python
# Always verify shapes at each step:
# X:       (batch, seq_len, d_model)
# Q, K, V: (batch, seq_len, d_k)  [after projection]
# scores:  (batch, seq_len, seq_len)
# weights: (batch, seq_len, seq_len)  [after softmax]
# output:  (batch, seq_len, d_v)

# For multi-head:
# Q, K, V: (batch, num_heads, seq_len, d_k)
# d_k = d_model // num_heads
```

### Numerical Stability in Softmax

```python
def stable_softmax(x: np.ndarray, axis: int = -1) -> np.ndarray:
    # ALWAYS subtract max before exp — prevents overflow
    x = x - x.max(axis=axis, keepdims=True)
    e = np.exp(x)
    return e / e.sum(axis=axis, keepdims=True)

# In attention with causal mask: use -1e9 (not -inf) for masked positions
# to avoid NaN in softmax
```

### KV Cache Memory Estimate

```python
def kv_cache_memory_gb(
    num_layers: int,
    num_heads: int,
    d_head: int,
    max_seq_len: int,
    batch_size: int,
    bytes_per_param: int = 2  # fp16
) -> float:
    """Estimate KV cache memory in GB."""
    # 2 = K and V
    total_bytes = (2 * num_layers * num_heads * d_head
                   * max_seq_len * batch_size * bytes_per_param)
    return total_bytes / (1024 ** 3)

# GPT-3 scale: 96 layers, 96 heads, d_head=128, seq
