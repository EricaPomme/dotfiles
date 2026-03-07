export OLLAMA_BASE_URL="http://localhost:11434/api"   # default per docs :contentReference[oaicite:6]{index=6}
export OLLAMA_MODEL="mistral:latest"
export OLLAMA_TEMPERATURE="0.7"

export PATH_PYTHON="/usr/bin/python3"

ask() {
  "$PATH_PYTHON" "$HOME/dotfiles/scripts/ollama.ask.py" "$@"
}

task2todo() {
  # deterministic on purpose for extraction
  OLLAMA_TEMPERATURE="${OLLAMA_TEMPERATURE_TODO:-0.2}" \
  "$PATH_PYTHON" "$HOME/dotfiles/scripts/ollama.task2todo.py" "$@"
}