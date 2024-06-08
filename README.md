# SolOS

A Docker-based dev environment and plugin system designed around the idea of passively collecting rich, clean, RAG-friendly data about the work a developer is doing. 

## Table of Contents
- [Requirements](#requirements)
- [Install](#install)
- [About](#about)
- [The Motivation](#the-motivation)
  - [Problem #1 - Laziness](#problem-1---laziness)
  - [Problem #2 - Lagging Context](#problem-2---lagging-context)
  - [Problem #3 - Context Segmentation](#problem-3---context-segmentation)
- [Show Don't Tell](#show-dont-tell)
- [Challenges](#challenges)
  - [Challenge #1 - Passive Data Collection](#challenge-1---passive-data-collection)
  - [Challenge #2 - Generic Implementation](#challenge-2---generic-implementation)

## Requirements

Ensure you have the following installed on your system:

- git
- docker
- curl
- bash
- code (the VSCode CLI command)

## Install

To install SolOS, execute the following commands in your terminal:

```shell
curl "https://raw.githubusercontent.com/InterBolt/solos/main/install.sh?token=$(date +%s)" -O
chmod +x ./install.sh
./install.sh
```

## About

At its core, SolOS is two things:

1. **Container-based dev environment**: Manages *projects* and *apps*. A *project* is a collection of *apps*. Similar to the git CLI, a new project is initialized by running `solos checkout <project_name>` in your host terminal. This command builds and runs a long-lived Docker container, generates a code-workspace file, and enables a custom Bash-based integrated terminal in VSCode.
   
2. **Plugin and tracking system**: Aims to collect meaningful information about the work a developer does throughout the day to provide personalized insights and guidance.

## The Motivation

The primary goal of SolOS is to provide a standard data-collection layer for future personalized Jarvis-like AI assistants. 

### Problem #1 - Laziness

A Jarvis-like AI assistant requires lots of **clean** data about the user, their work habits, and codebases they are working on. A well-designed RAG (Retrieval-Augmented Generation) system is needed to interact with this data. My initial attempts to build such a system suffered from the problem of **human laziness**.

While a naive CLI or GUI system showed promise initially, it quickly became apparent that forgetting to provide necessary information due to bad sleep or looming deadlines led to incomplete data. This degraded the performance of the AI assistant, making it less knowledgeable and ultimately leading to its abandonment.

### Problem #2 - Lagging Context

Even with disciplined note-taking, my AI assistants were suboptimal. Old notes became confusing when features were changed, requiring tedious corrections. This led to a loss of confidence in the AI’s responses, as I had to verify its context often, negating much of its benefit.

### Problem #3 - Context Segmentation

Tagging notes with project names to tailor the AI’s responses added complexity. Notes often pertained to multiple projects, requiring rewording and re-tagging, which was cumbersome and led to inconsistencies.

## Show Don't Tell

A successful LLM-based Jarvis system must rely on passive data collection techniques, as developers cannot be relied upon to consistently provide detailed input. The AI needs to know what to look for, when to interject, and how to parse actions and outputs based on passive observations.

## Challenges

Building a generic system where an AI can passively "observe" a developer's work poses several challenges:

### Challenge #1 - Passive Data Collection

*Implement passive data collection mechanisms that can unobtrusively gather information about a developer's actions, decisions, and context without requiring manual input.*

### Challenge #2 - Generic Implementation

*Design a system that can adapt to the diverse workflows of different developers. This involves creating modular, customizable components that can handle various development environments, tools, and practices.*

By addressing these challenges, SolOS aims to create a robust AI development assistant capable of providing insightful and personalized guidance without disrupting the developer's workflow.