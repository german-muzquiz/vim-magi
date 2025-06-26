# Magi

Vim plugin for AI coding assitance.

## Overview

This is a vim plugin with a python backend that integrates vim with different AI models and tools for coding assistance workflows.

Integration points

- API keys (OpenAI, Anthropic, Google, Openrouter)
- MCP servers 
- Vendor CLI clients (Claude Code, Gemini Cli)
- Manual copy/paste between vendor web chats and vim

## Installation

Install via [Vim-Plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'german-muzquiz/vim-magi'
```

### Prerequisites

- Python 3

## Usage

Available commands

- **Magi**: Opens a new buffer in chat mode
- **MagiPlan**: Plan a change, feature or task, intelligently building the right context
- **MagiExecute**: Implements a plan
- **MagiDebug**: Troubleshoot and fix an issue
- **MagiConfig**: Open configuration file

## Configuration

Running the command `MagiConfig` will open the configuration file located at `~/.magi/config.yml`.

```yaml
magi:
  api_keys:
    openai: "sk-..."
    anthropic: "..."
    google: "..."
    openrouter: "..."
  workflows:  # cmd values follow the format api|mcp|cli|web[/<vendor>[/<model name>]]
    chat: 
      cmd: cli/claude
    plan: 
      context_cmd: mcp/repoprompt
      plan_cmd: mcp/repoprompt
    execute: 
      cmd: api/openrouter/anthropic/claude-sonnet-4
    debug: 
      cmd: cli/gemini
  mcp_servers:
    repoprompt:
      command: ~/RepoPrompt/repoprompt_cli
      args: []
  prompts:
    dirs:
      - ~/.magi/prompts
```

The config file can reference environment variables:

```yaml
magi:
  api_keys:
    openai: "$OPENAI_API_KEY"
```
