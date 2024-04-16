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

## AI

Solos includes a small but powerful AI feature. Once Solos is installed a developer can write something like the following:

```shell
ai --note link -sfv some-file some-other-file
```

When this command is executed, either in a script or on the CLI, Solos will intercept the command, strip away the ai portion of the command (eg `link -sfv some-file some-other-file`), and do a few things before running it:

* First, the `ai` command alerts the shell's builtin preexec hook to log as much information about the command as possible, some info about our dev container at the time, specific portions of the comamnd's stdout/err, among potentially other things.
* The `--note` flag tells the builtin preexec hook to first prompt the user for extra info before running the command. 

As a developer is going through their daily paces, they can use Solos' `ai ...` prefix command to build a rich log of key commands they ran throughout the day. These logs are useful without AI but can serve as the basis for generating personalized feedback down the road. Additionally, the logs for various commands make it possible to enhance the data furthur using something like the Github Copilot CLI to explain what the command does and to suggest improvements.

The `work => review => AI feedback loop` should have compounding benefits over time.

## Background

Solos is my attempt to bottle my (ideal) development workflow into a single CLI. The `solos` command that gets installed to your path will let you launch new "server pairs", where one of the paired servers is a prod environment, and the other is a local docker container, built to mimic the prod environment.

The CLI automates annoying tasks such as:

* setting up SSH keys, vscode configs, provisioning, backing up, and restoring infrastructure.
* persisting and managing environment secrets and variables across a range of individual applications.
* exposing hooks to deploy containerized applications via Caprover and managing per-application or multi-application postgres databases.

## The problem

Solos came out of my frustration with dev SAAS tooling. Many SAAS developer tools market themselves as a more robust alternative to some DIY process. And they're often right!

But after 10 years of writing software, I'm frustrated with certain aspects of SAAS-driven development:

* Services randomly going out of business. Looking at you hosted DB companies.

* Pricing structures that don't make sense when all I need is a tiny bit of compute.

* So many fucking accounts - unexpectedly getting hit with an exorbitant annual subscription fee because I forgot to cancel that one service I tried last spring and totally thought I would need for the whole year.

* Executive paralysis. I find myself doing anything to avoid having to re-visit old projects that rely on multiple SAAS's that I haven't touched in months. Login flows where I need to constantly reset my password or rely on a weird 2FA process, refamiliarizing myself with their proprietary quirks, reviewing relevant or breaking feature changes, busted UIs, the fear of finding a bug specific to their proprietary and underdocumented code, etc etc. All super annoying.

I could probably write a 2000 word blog post on why I hate getting tangled up in multiple SAAS providers, but you get the point.

## The alternative

In one word: linux.

Linux tools don't come with the same sexy marketing as their "modern" saas alternatives, and advanced linux knowledge is concentrating more and more into a shrinking number of developers, even if a surface level understanding is growing (thanks Docker). But linux is amazing! 

I spent years avoiding it, thinking that it was too "low level" for a humble application developer like myself. But a couple things happened over the past two years that changed my mind:

1) I needed a complex dockerized bash script for one of my projects.
2) I was an avid user Github Copilot.

I'd seen a lot of generated Copilot code, but getting in the weeds with Bash led to realize something: LLMs do a remarkable job at generating shell code, specifically Bash. And it makes sense. Bash and the linux commands that Copilot is so good at generating are quite old in comparison to more modern languages like JS or Ruby. Surely there's a richer archive of training data for common Unix commands and Bash than there is for more modern tools like Rust and Docker. Not too mention, the older software content probably doesn't suffer as much from the hyper-spam SEO content inflation problem that modern software does.

Oh, and Bash doesn't change much. The Bash version 3.2 code I'm writing for Solos in 2024 could be transmitted back in time to a developer working on a much lower spec'd machine in 2009 and they'd have no trouble running it. If the internal implementations for modern LLM's involve a pre-processing step on training data that tags or disposes of outdated information, I'd imagine content written about Bash would get disposed of far less often than say content about frontend JavaScript. While I can only speculate on an LLM's internal implementation, I can confirm that I am far quicker to use a RAG-based system like Phind over ChatGPT for a question about Webpack.

## How it works

After installation, running the `solos` command will do the following:

* check your environment to see if you're either on a valid Debian 12 machine, or have docker installed.
* if you're already running debian 12, Solos will directly invoke it's main script at `solos/bin/solos.sh`.
* if you're not running debian 12 but you have docker installed, Solos will instead run a one-off container to invoke the `solos/bin/solos.sh` script.