#!/bin/zsh
# Tutorial setup — source this file before starting: source setup.sh

echo "[setup] Installing Jaseci (standalone)..."
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --standalone || true

# Add ~/.local/bin to PATH for this session and future sessions
export PATH="$HOME/.local/bin:$PATH"
if ! grep -q 'HOME/.local/bin' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
fi

alias jac='jac 2> >(grep -v "layout-compatible" >&2)'

echo ""
echo "[setup] Done! When you receive your OpenAI API key, run:"
echo "        export OPENAI_API_KEY=\"your-key-here\""
echo ""
echo "        Then start the tutorial with: jac run code/step1_genarate.jac"