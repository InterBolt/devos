# Solos - A solo hacker's PAAS

A bash CLI designed to automate the hairy parts of doing end-to-end development and deployment on Debian.

## System requirements

* docker
* git
* curl
* bash 3 or above

## Installation

Install `solos` to your path:

```shell
curl -s "https://raw.githubusercontent.com/InterBolt/solos/main/install.sh?token=$(date +%s)" | bash
```

That's it.

## Documentation

TODO

## Background

Solos is an attempt to bottle my (ideal) development workflow into a single CLI. The `solos` command that gets installed to your path will let you launch new "server pairs", where one of the paired servers is a prod environment, and the other is a local docker container built to mimic the prod environment.

The CLI automates annoying tasks such as:

* setting up SSH keys, vscode configs, provisioning, backing up and restoring infrastructure.
* persisting and managing environment secrets and variables across a range of individual applications.
* exposing hooks to deploy containerized applications via Caprover and managing per-application or multi-application postgres databases.

## The AI cherry on top

Solos includes a small but powerful AI feature. Once Solos is installed a developer can write something like the following:

```shell
ai --note link -sfv some-file some-other-file
```

When this command is executed, either in a script or on the CLI, Solos will intercept the command, strip away the ai portion of the command (leaving just `link -sfv some-file some-other-file`), and do a few things before running it:

* First, the `ai` command alerts the shell's builtin preexec hook to log as much information about the command as possible, some info about our dev container at the time, specific portions of the comamnd's stdout/err, among potentially other things.
* The `--note` flag tells the builtin preexec hook to first prompt the user for extra info before running the command. 

As a developer is going through their daily paces, they can use Solos' `ai ...` prefix command to build a rich log of key commands they ran throughout the day. These logs are useful without AI, even if only for auditing purposes, but could also serve as the basis for generative feedback tools tailored to a single developer.

The `work => review => AI feedback loop` should have compounding benefits over time as the log data grows, the developer gets better at knowing when to log, and LLM context windows grow. Imagine using this tool for an entire year, gathering megabytes worth of logs and then running those through a sophisticated RAG system to understand where you've grown, how you can improve, products you might want to use to replace manual things you're doing, etc.

## Why I built Solos

Many SAAS developer tools market themselves as a more robust alternative to some DIY process. And in the context of a company or startup, they're usually right. But as a solo developer who enjoys launching lots of little websites and tools, and who rarely has the patience to focus on a single thing, I found myself drowning in services and subscriptions.

There were few reasons why I felt this way:

* Services randomly going out of business. Looking at you hosted DB companies.

* Pricing structures that don't make sense when all I need is a tiny bit of compute.

* So many fucking accounts - unexpectedly getting hit with an exorbitant annual subscription fee because I forgot to cancel that one service I tried last spring and totally thought I would need for the whole year.

* Executive paralysis. I found myself doing anything to avoid having to re-visit old projects that rely on multiple SAAS's that I haven't touched in months. Login flows where I need to constantly reset my password or rely on a weird 2FA process, refamiliarizing myself with their proprietary quirks, reviewing relevant or breaking feature changes, busted UIs, the fear of finding a bug specific to their proprietary and underdocumented code, etc etc. All super annoying.

I could probably write a 2000 word blog post on why I hate getting tangled up in multiple SAAS providers, but you get the point.

## The alternative

In one word: linux.

Linux tools don't come with the same sexy marketing as their "modern" saas alternatives, and advanced linux knowledge is concentrating more and more into a shrinking number of developers, even if a surface level understanding is growing (thanks Docker). But linux is amazing! 

I spent years believing that it was too "low level" for a humble application developer like myself. But a couple things happened over the past two years that changed my mind:

1) I needed a complex dockerized bash script for one of my projects.
2) I was an avid Github Copilot user.

I'd seen a lot of generated Copilot code, but getting in the weeds with Bash led to realize something: LLMs do a remarkable job at generating shell code, specifically Bash. And it makes sense. Bash and the linux commands that Copilot is so good at generating are old in comparison to more modern languages like JS or Ruby. Surely there's a richer archive of training data for common Unix commands and Bash than there is for more modern tools like Rust and Docker. Not too mention, the older software content probably doesn't suffer as much from the SEO content inflation problem.

Oh, and Bash doesn't change much. The Bash v3 code I'm writing for Solos in 2024 could be transmitted back in time to a developer working on a much lower spec'd machine in 2009 and they'd have no trouble running it. Commands like "docker" wouldn't work, but the point is that the script could be loaded and interpreted by Bash all the same. If the internal implementations for modern LLM's involve a pre-processing step on training data that tags or disposes of outdated information, I'd imagine content written about Bash would get disposed of less often than content about ReactJS. While I can only speculate on an LLM's internal implementation, I know I'm far quicker to use a RAG-based system like Phind over ChatGPT for a question about Webpack.